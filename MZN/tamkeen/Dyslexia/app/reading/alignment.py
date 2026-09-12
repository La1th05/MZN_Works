def align_words(expected_text, recognized_text):
    expected = expected_text.strip().split()
    recognized = recognized_text.strip().split()

    n = len(expected)
    m = len(recognized)

    # Dynamic Programming matrix
    dp = [[0] * (m + 1) for _ in range(n + 1)]

    # If recognized text is empty -> all expected words are omissions
    for i in range(1, n + 1):
        dp[i][0] = i

    # If expected text is empty -> all recognized words are insertions
    for j in range(1, m + 1):
        dp[0][j] = j

    # Fill DP matrix
    for i in range(1, n + 1):
        for j in range(1, m + 1):

            if expected[i - 1] == recognized[j - 1]:
                substitution_cost = 0
            else:
                substitution_cost = 1

            dp[i][j] = min(
                dp[i - 1][j] + 1,                     # omission
                dp[i][j - 1] + 1,                     # insertion
                dp[i - 1][j - 1] + substitution_cost  # correct/substitution
            )

    # Backtracking
    alignment = []

    i = n
    j = m

    while i > 0 or j > 0:

        # Correct word
        if (
            i > 0
            and j > 0
            and expected[i - 1] == recognized[j - 1]
            and dp[i][j] == dp[i - 1][j - 1]
        ):

            alignment.append({
                "position": i - 1,
                "expected": expected[i - 1],
                "spoken": recognized[j - 1],
                "type": "correct"
            })

            i -= 1
            j -= 1

        # Substitution
        elif (
            i > 0
            and j > 0
            and dp[i][j] == dp[i - 1][j - 1] + 1
        ):

            alignment.append({
                "position": i - 1,
                "expected": expected[i - 1],
                "spoken": recognized[j - 1],
                "type": "substitution"
            })

            i -= 1
            j -= 1

        # Omission
        elif (
            i > 0
            and dp[i][j] == dp[i - 1][j] + 1
        ):

            alignment.append({
                "position": i - 1,
                "expected": expected[i - 1],
                "spoken": None,
                "type": "omission"
            })

            i -= 1

        # Insertion
        else:

            alignment.append({
                "position": i,
                "expected": None,
                "spoken": recognized[j - 1],
                "type": "insertion"
            })

            j -= 1

    # Backtracking produced reverse order
    alignment.reverse()

    # Detect simple repetitions.
    #
    # Example:
    # expected: the cat
    # spoken:   the the cat
    #
    # One "the" will initially be an insertion.
    # We change it to repetition.
    for index, item in enumerate(alignment):

        if item["type"] != "insertion":
            continue

        inserted_word = item["spoken"]

        previous_spoken = None
        next_spoken = None

        # Find previous spoken word
        for previous_index in range(index - 1, -1, -1):

            if alignment[previous_index]["spoken"] is not None:
                previous_spoken = alignment[previous_index]["spoken"]
                break

        # Find next spoken word
        for next_index in range(index + 1, len(alignment)):

            if alignment[next_index]["spoken"] is not None:
                next_spoken = alignment[next_index]["spoken"]
                break

        if inserted_word == previous_spoken or inserted_word == next_spoken:
            item["type"] = "repetition"

    correct_count = sum(
        1
        for item in alignment
        if item["type"] == "correct"
    )

    return alignment, correct_count