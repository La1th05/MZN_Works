import string
import re

def normalize_text(text,language):
    if language == 'English':
        text = text.lower()
        
        text = re.sub(r'(\S)\1{2,}', r'\1',text)
        
        text = re.sub(r'[^\w\s]|_','',text)
        
        text = re.sub(r'\s+', ' ', text).strip()
    elif language == 'Arabic' :
        text = text = re.sub(r'ـ', '', text)
        table=str.maketrans('','','ًٌٍَُِّْ')
        
        text=text.translate(table)
        text = re.sub(r'\s+', ' ', text).strip()
    return text
        
