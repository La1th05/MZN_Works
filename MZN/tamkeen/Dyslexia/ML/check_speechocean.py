from datasets import load_dataset, Audio


print("STEP 1: Starting...")


dataset = load_dataset(
    "mispeech/speechocean762"
)


print("\nSTEP 2: Dataset downloaded/loaded.")

print("\nTYPE:")
print(type(dataset))

print("\nFULL DATASET:")
print(dataset)


dataset = dataset.cast_column(
    "audio",
    Audio(decode=False)
)


print("\nAVAILABLE SPLITS:")
print(dataset.keys())


print("\nTRAIN ROWS:")
print(len(dataset["train"]))


print("\nTEST ROWS:")
print(len(dataset["test"]))


print("\nFIRST TRAIN SAMPLE:")
sample = dataset["train"][0]

print(sample.keys())

print("\nTEXT:")
print(sample["text"])

print("\nAGE:")
print(sample["age"])

print("\nAUDIO INFORMATION:")

audio = sample["audio"]

print("Audio path:")
print(audio.get("path"))

audio_bytes = audio.get("bytes")

if audio_bytes:
    print("Audio bytes:", len(audio_bytes))
else:
    print("Audio bytes: 0")