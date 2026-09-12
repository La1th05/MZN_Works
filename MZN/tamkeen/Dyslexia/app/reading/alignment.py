def align_words(expected_text, recognized_text):
    expected = expected_text.strip().split()
    recognized = recognized_text.strip().split()
    
    n = len(expected)
    m = len(recognized)
    
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    
    for i in range(1, n + 1):
        dp[i][0] = i
    for j in range(1, m + 1):
        dp[0][j] = j
        
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if expected[i - 1] == recognized[j - 1]:
                cost = 0  
            else:
                cost = 1  
                
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,    
                dp[i - 1][j - 1] + cost 
            )
            
    i, j = n, m
    alignment = []
    correct_count = 0  # Added counter for correct words
    
    while i > 0 or j > 0:
        if i > 0 and j > 0 and expected[i - 1] == recognized[j - 1]:
            alignment.append({
                "expected": expected[i - 1],
                "recognized": recognized[j - 1],
                "status": "correct"
            })
            correct_count += 1  # Increment on correct match
            i -= 1
            j -= 1
        elif i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + 1:
            alignment.append({
                "expected": expected[i - 1],
                "recognized": recognized[j - 1],
                "status": "substituted"
            })
            i -= 1
            j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            alignment.append({
                "expected": expected[i - 1],
                "recognized": None,
                "status": "omitted"
            })
            i -= 1
        else:
            alignment.append({
                "expected": None,
                "recognized": recognized[j - 1],
                "status": "inserted"
            })
            j -= 1
            
    return alignment[::-1], correct_count
