"""
Attention dispersion metrics.

ADS is used by PHG as a compactness proxy.

Lower ADS:
    attention is concentrated / compact

Higher ADS:
    attention is diffuse / spread across the image
"""

from __future__ import annotations

from typing import Any, Dict, Optional, Tuple

import numpy as np
import torch

try:
    from scipy.ndimage import label
except ImportError as exc:
    raise ImportError(
        "grounding.ads requires scipy. Install with: pip install scipy"
    ) from exc

from grounding.grid import image_attn_to_grid


def spatial_entropy(
    attn_map_2d: torch.Tensor,
    threshold: float = 1e-3,
) -> Dict[str, Any]:
    """
    Compute component-level spatial entropy for a 2D attention map.

    This is used to select compact layer-head maps.

    Args:
        attn_map_2d:
            Tensor with shape [H, W].

        threshold:
            Threshold over activated attention.

    Returns:
        {
            "spatial_entropy": float,
            "labeled_array": np.ndarray,
            "num_components": int,
        }
    """

    attn_map_2d = attn_map_2d.detach().float().cpu()

    normalized = (
        attn_map_2d - attn_map_2d.min()
    ) / (
        attn_map_2d.max() - attn_map_2d.min() + 1e-8
    )

    mean_val = torch.mean(normalized)
    activated = torch.relu(normalized - mean_val * 2.0)

    activated_np = activated.numpy()
    binary = (activated_np > threshold).astype(np.int32)

    labeled_array, num_components = label(
        binary,
        structure=np.ones((3, 3), dtype=np.int32),
    )

    total = float(activated.sum().item())

    if total <= 0:
        return {
            "spatial_entropy": float("inf"),
            "labeled_array": labeled_array,
            "num_components": 0,
        }

    probs = []

    for component_id in range(1, num_components + 1):
        component_sum = activated_np[labeled_array == component_id].sum()

        if component_sum > 0:
            probs.append(component_sum / total)

    if len(probs) == 0:
        entropy = 0.0
    else:
        entropy = -sum(p * np.log(p) for p in probs if p > 0)

    return {
        "spatial_entropy": float(entropy),
        "labeled_array": labeled_array,
        "num_components": int(num_components),
    }


def compute_ads_from_attention_map(
    attn_map_2d: torch.Tensor,
    foreground_ratio: float = 0.10,
    min_component_size: int = 3,
    eps: float = 1e-8,
) -> float:
    """
    Compute ADS (Attention Dispersion Score) following Nguyen et al.

    Given an aggregated continuous attention map Ā_o:
    Args:
        attn_map_2d:
            Aggregated attention map with shape [H, W].

        foreground_ratio:
            Top ratio of activated patches treated as foreground candidates
            (empirically x = 0.10).

        min_component_size:
            Minimum component area to retain after grouping.

    Returns:
        ADS score. Lower is more compact.
    """

    attn_map_2d = attn_map_2d.detach().float().cpu()
    attn_map_2d = torch.clamp(attn_map_2d, min=0)

    attn_np = attn_map_2d.numpy()
    H, W = attn_np.shape
    num_patches = H * W

    flat = attn_np.flatten()
    total = float(flat.sum())

    if total <= eps:
        return float("inf")

    threshold = np.percentile(flat, 100.0 * (1.0 - foreground_ratio))
    binary = (flat >= threshold).reshape(H, W).astype(np.int32)

    if not binary.any():
        foreground_mass = 0.0
        # All patches are background
        probs = flat / (total + eps)
        entropy = -float(np.sum(probs * np.log(probs + eps)))
        background_entropy = entropy / float(np.log(max(num_patches, 2)))
        return float((1.0 - foreground_mass) * background_entropy)

    labeled_array, num_components = label(
        binary,
        structure=np.ones((3, 3), dtype=np.int32),
    )

    valid_components: set[int] = set()
    for comp_id in range(1, num_components + 1):
        area = int(np.sum(labeled_array == comp_id))
        if area >= min_component_size:
            valid_components.add(comp_id)

    foreground_mask = np.zeros((H, W), dtype=bool)
    for comp_id in valid_components:
        foreground_mask[labeled_array == comp_id] = True
    background_mask = ~foreground_mask

    foreground_mass = float(attn_np[foreground_mask].sum())

    background_attn = attn_np[background_mask]
    background_sum = float(background_attn.sum())

    if background_sum <= eps or background_attn.size == 0:
        background_entropy = 0.0
    else:
        E_o = background_attn / (background_sum + eps)
        entropy = -float(np.sum(E_o * np.log(E_o + eps)))
        background_entropy = entropy / float(np.log(max(num_patches, 2)))

    ads = (1.0 - foreground_mass) * background_entropy

    return float(ads)


def compute_ads_from_step(
    step: Dict[str, Any],
    image_grid_shape: Optional[Tuple[int, int]] = None,
    inputs: Optional[Dict[str, Any]] = None,
    foreground_ratio: float = 0.10,
    top_n_heads: int = 3,
    attn_sum_threshold: float = 0.49,
) -> float:
    """
    Compute ADS on the aggregated continuous attention map Ā_o.

    Aggregates the top-N selected layer-head maps by averaging into a single
    attention map Ā_o, then computes ADS on that aggregated map following the
    formulation in Section 3.7.5 (Nguyen et al. [94]).

    The step must contain:
        step["image_attn_by_layer"][layer_id] = Tensor[num_heads, num_image_tokens]

    Returns:
        ADS score on the aggregated map. Lower is more compact.
    """

    from grounding.attention import get_kept_lh_from_step

    kept = get_kept_lh_from_step(
        step=step,
        image_grid_shape=image_grid_shape,
        inputs=inputs,
        attn_sum_threshold=attn_sum_threshold,
    )

    if len(kept) == 0:
        return float("inf")

    image_attn_by_layer = step["image_attn_by_layer"]
    agg_maps: list[torch.Tensor] = []

    for selected in kept[:top_n_heads]:
        layer_id = selected["layer"]
        head_id = selected["head"]

        image_attn = image_attn_by_layer[layer_id].detach().float().cpu()
        attn_1d = image_attn[head_id]

        # Reject cached-step attention (single-token).
        if int(attn_1d.numel()) <= 1:
            continue

        attn_2d = image_attn_to_grid(
            attn_1d,
            image_grid_shape=image_grid_shape,
            inputs=inputs,
        )

        attn_2d = attn_2d.detach().float().cpu()
        attn_2d = torch.clamp(attn_2d, min=0)

        attn_sum = attn_2d.sum()

        if float(attn_sum.item()) <= 1e-8:
            continue

        attn_2d = attn_2d / (attn_sum + 1e-8)

        agg_maps.append(attn_2d)

    if len(agg_maps) == 0:
        return float("inf")

    aggregated: torch.Tensor = torch.stack(agg_maps, dim=0).mean(dim=0)

    return compute_ads_from_attention_map(
        aggregated,
        foreground_ratio=foreground_ratio,
    )