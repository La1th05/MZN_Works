def clamp(value, minimum=0.0, maximum=1.0):
    """
    Keep a numeric value between minimum and maximum.
    """
    return max(minimum, min(maximum, value))

def infer_skill_evidence(
    metrics,
    errors,
    ml_predictions=None,
    target_wpm=60.0,
    good_accuracy_threshold=0.90,
    word_recognition_threshold=0.85
):
    """
    Convert reading metrics/errors and ML predictions into educational skill evidence.
    """
    skill_updates = []

    accuracy = metrics.get("accuracy")
    wpm = metrics.get("wpm")
    words_expected = metrics.get("words_expected", 0)
    substitutions = metrics.get("substitutions", 0)
    omissions = metrics.get("omissions", 0)
    repetitions = metrics.get("repetitions", 0)

    # =========================================
    # 1. WORD RECOGNITION (From Raw Metrics)
    # =========================================
    if words_expected > 0 and accuracy is not None:
        recognition_errors = substitutions + omissions
        recognition_error_rate = recognition_errors / words_expected

        accuracy_signal = 1.0 - accuracy
        error_signal = recognition_error_rate
        word_recognition_evidence = clamp(max(accuracy_signal, error_signal))

        if accuracy < word_recognition_threshold or recognition_error_rate >= 0.15:
            reasons = []
            if accuracy < word_recognition_threshold:
                reasons.append(f"Reading accuracy is {accuracy:.2f}")
            if substitutions > 0:
                reasons.append(f"{substitutions} substitution(s)")
            if omissions > 0:
                reasons.append(f"{omissions} omission(s)")

            skill_updates.append({
                "skill_code": "READ.WORD_RECOGNITION",
                "evidence": round(word_recognition_evidence, 3),
                "status": "needs_support",
                "reason": "; ".join(reasons)
            })

    # =========================================
    # 2. FLUENCY (From Raw Metrics)
    # =========================================
    if (accuracy is not None and wpm is not None and target_wpm is not None and target_wpm > 0):
        if accuracy >= good_accuracy_threshold and wpm < target_wpm:
            speed_ratio = wpm / target_wpm
            fluency_evidence = clamp(1.0 - speed_ratio)

            reasons = [
                f"Accuracy is good ({accuracy:.2f})",
                f"WPM is {wpm:.1f}",
                f"Target WPM is {target_wpm:.1f}"
            ]
            if repetitions > 0:
                reasons.append(f"{repetitions} repetition(s)")
                fluency_evidence = clamp(fluency_evidence + min(0.20, repetitions * 0.05))

            skill_updates.append({
                "skill_code": "READ.FLUENCY",
                "evidence": round(fluency_evidence, 3),
                "status": "needs_support",
                "reason": "; ".join(reasons)
            })

    # =========================================
    # 3. ML PREDICTIONS (SpeechOcean Targets)
    # =========================================
    if ml_predictions is not None:
        # If the model estimates a low fluency score (e.g., < 8.0 out of 10)
        expert_fluency = ml_predictions.get("expert_fluency")
        if expert_fluency is not None and expert_fluency < 8.0:
            evidence_strength = clamp((8.0 - expert_fluency) / 8.0)
            skill_updates.append({
                "skill_code": "READ.FLUENCY",
                "evidence": round(evidence_strength, 3),
                "status": "needs_support",
                "reason": f"Model estimated fluency score requires support: {expert_fluency:.1f}/10"
            })
            
        # If the model estimates a low prosody score
        expert_prosodic = ml_predictions.get("expert_prosodic")
        if expert_prosodic is not None and expert_prosodic < 8.0:
            evidence_strength = clamp((8.0 - expert_prosodic) / 8.0)
            skill_updates.append({
                "skill_code": "READ.PROSODY",
                "evidence": round(evidence_strength, 3),
                "status": "needs_support",
                "reason": f"Model estimated prosody/expression requires support: {expert_prosodic:.1f}/10"
            })

    # =========================================
    # 4. DEDUPLICATE SKILLS
    # =========================================
    # If both raw metrics and ML flagged the same skill (e.g. READ.FLUENCY), keep the strongest evidence.
    merged_updates = {}
    for update in skill_updates:
        code = update["skill_code"]
        if code not in merged_updates or update["evidence"] > merged_updates[code]["evidence"]:
            merged_updates[code] = update
            
    return list(merged_updates.values())