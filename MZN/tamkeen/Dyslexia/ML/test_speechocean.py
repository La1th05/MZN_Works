from datasets import load_dataset, Audio


print("Loading SpeechOcean762...")


dataset = load_dataset(
    "mispeech/speechocean762"
)


# Disable automatic audio decoding.
dataset = dataset.cast_column(
    "audio",
    Audio(decode=False)
)


print("\n========== DATASET ==========\n")

print(dataset)


print("\nTrain rows:")
print(len(dataset["train"]))


print("\nTest rows:")
print(len(dataset["test"]))


print("\n========== FIRST SAMPLE ==========\n")

sample = dataset["train"][0]


for key, value in sample.items():

    if key != "audio":
        print(f"{key}: {value}")


print("\nAudio reference:")
print(sample["audio"])