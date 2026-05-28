from faithscore.framework import FaithScore

images = ["./COCO_val2014_000000164255.jpg"]
answers = ["The main object in the image is a colorful beach umbrella."]

scorer = FaithScore(vem_type="...", api_key="...", llava_path=".../llava/eval/checkpoints/llava-v1.5-13b", use_llama=False,
                   llama_path="...llama2/llama-2-7b-hf")
score, sentence_score = scorer.faithscore(answers, images)