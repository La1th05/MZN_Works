from alignment import align_words 

def word_metrics (expected_text, recognized_text,time_taken):
    words_expected = len (expected_text.strip().split())
    words_spoken = len (recognized_text.strip().split())
    
    sentence,words_correct = align_words(expected_text, recognized_text)
    omissions = 0
    substitutions = 0
    insertions = 0
    for word in sentence :
        for state in word["status"] :
            if state == "correct" :
                continue
            elif state == "omitted":
                omissions+=1
            elif state == "substituted":
                substitutions+=1
            elif state == "inserted":
                insertions+=1
        num_of_wrong_words= {"omitted":omissions,"substituted":substitutions,"inserted":insertions}
    reading_accuracy  = words_correct / words_expected
    
    
    duration_in_minutes = time_taken/60
    if duration_in_minutes != 0 :
        WPM = words_spoken / duration_in_minutes
    else :
        "Time Cannot be zero"
        
    return(reading_accuracy,WPM, num_of_wrong_words)
