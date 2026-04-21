def filter_kz_numbers(numbers: List[str]) -> List[str]:
    accepted = []
    for n in numbers:
        digits = "".join(ch for ch in n if ch.isdigit())
        if len(digits) == 10:
            digits = "7" + digits
        elif len(digits) == 11 and digits.startswith("8"):
            digits = "7" + digits[1:]
        if len(digits) == 11 and digits.startswith("7"):
            accepted.append(digits)
    return accepted
