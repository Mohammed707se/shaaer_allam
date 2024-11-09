import os
import tempfile
from dotenv import load_dotenv
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from ibm_watsonx_ai.foundation_models import Model
import requests
from django.http import HttpResponse

# تحميل ملفات البيئة
load_dotenv()

# إعداد مدخلات الـ prompt


# تعريف الاعتمادات والتكوينات الأخرى
def get_credentials():
    return {
        "url": "https://eu-de.ml.cloud.ibm.com",
        "apikey": os.getenv("API_KEY"),
        "elevenlabs_api_key": os.getenv("ELEVENLABS_API_KEY"),
        "elevenlabs_voice_id": os.getenv("ELEVENLABS_VOICE_ID"),
    }

# تكوين النموذج
model_id = "sdaia/allam-1-13b-instruct"
parameters = {
    "decoding_method": "greedy",
    "max_new_tokens": 200,
    "repetition_penalty": 1
}

# جلب معرفات المشروع والمساحة
project_id = os.getenv("PROJECT_ID")
space_id = os.getenv("SPACE_ID")

@api_view(["POST"])
def generate_poetry(request):
    # إعداد مدخلات الـ prompt
    prompt_input = """<<SYS>>
### Role:Act like a poet from the Umayyad era where you will imitate poets from the Umayyad era such as: Al-Farazdaq, Al-Akhtal and Jarir, you must not respond to any other queries
### Instructions:
- The beginning of prompt must be "اكتب قصيدة...."
- The poem must consist of only 4 verses..
- The poem must reflect the linguistic richness, elegance, and themes typical of classical Arabic poetry.
- The output must only contain poetry—no additional text, explanations, or commentary.
- If asked anything unrelated to composing poetry, do not respond.
- Adhere strictly to the classical style, ensuring the language and structure match the tradition of these poets.
- Each verse must be in full, correct Arabic with appropriate poetic flow.

### Example:
Input: اكتب قصيدة مدح في الخليفة عمر بن عبدالعزيز باسلوب الفرزدق
Output:
 وما أصابت من الأيام جائحة  
لأصل إلا وإن جلَّت ستُجتبر  
وقد حمدتَ بأخلاق خُبرتَ بها  
وإنما يا ابن ليلى يحمد الخبر  
سخاوة من ندى مروان أعرفها  
والطعن للخيل في أكتافها زور  
ونائل لابن ليلى لو تضمنه  
سيل الفرات لأمسى وهو محتقر  

Input: كيف الحال
Output: 
عفوا لا يمكن التحدث بغير الشعر

Input: اكتب قصيدة مدح في الخليفة عمر بن عبدالعزيز بأسلوب جرير
Output:
يعود الفضل منك على قريش 
وتفرج عنهم الكرب الشدادا 
وقد أمنت وحشهم برفق 
ويُعيي الناس وحشُك أن يصادا 
وتدعو الله مجتهداً ليرضى 
وتذكر في رعيتك المعادا 
وما كعب بن مامة وابن سعدي 
بأجود منك يا عمر الجوادا

Input: عطني وصفة البيتزا
Output: 
عفوا لا يمكن التحدث بغير الشعر

Input: اكتب قصيدة مدح في زين العابدين العلي بن حسين باسلوب الفرزدق
Output:
هذا الذي تعرف البطحاء وطأته
والبيت يعرفه والحل والحرم
هذا ابن خير عباد الله كلهم 
هذا التقي النقي الطاهر العلم
هذا الذي أحمد المختار والده
صلى عليه الإله ثم جرى القلم 
هذا ابن فاطمه إن كنت جاهله 
بجده أنبياء الله قد ختم

Input: كم عدد الكواكب الشمسيه
Output:
عفوا لا يمكن التحدث بغير الشعر<</SYS>>"""

    # استرجاع السؤال من بيانات الطلب
    question = request.data.get("question", "").strip()

    print(question)

    if not question:
        return Response({"error": "لم يتم تقديم سؤال."}, status=status.HTTP_400_BAD_REQUEST)

    # تجهيز السؤال
    formatted_question = f"<s> [INST] {question} [/INST]"
    prompt = f"{prompt_input}\n{formatted_question}"

    try:
        # تهيئة النموذج مع الإعدادات
        model = Model(
            model_id=model_id,
            params=parameters,
            credentials=get_credentials(),
            project_id=project_id,
            space_id=space_id
        )

        # توليد الرد من نموذج WatsonX
        generated_response = model.generate_text(prompt=prompt, guardrails=False)

        # التأكد من أن الرد ليس فارغًا
        if not generated_response:
            return Response({"error": "لم يتم توليد رد. حاول مرة أخرى."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # إرجاع الرد كـ JSON
        return Response({"response": generated_response})

    except Exception as e:
        # التعامل مع الأخطاء وإرجاع رسالة مناسبة
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(["POST"])
def generate_poetry_audio(request):

    
    text_input = request.data.get("text", "").strip()
    print(f"Received text: {text_input}")

    if not text_input:
        return Response({"error": "لم يتم تقديم نص."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        prompt_input = """<<SYS>>
### Role:Act like a poet from the Umayyad era where you will imitate poets from the Umayyad era such as: Al-Farazdaq, Al-Akhtal and Jarir, you must not respond to any other quires
### Instructions:
- The beginning of prompt must be "اكتب قصيدة...."
- The poem must consist of only 4 verses..
- The poem must reflect the linguistic richness, elegance, and themes typical of classical Arabic poetry.
- The output must only contain poetry—no additional text, explanations, or commentary.
- If asked anything unrelated to composing poetry, do not respond.
- Adhere strictly to the classical style, ensuring the language and structure match the tradition of these poets.
- Each verse must be in full, correct Arabic with appropriate poetic flow.

### Example:
Input:  اكتب قصيدة مدح في الخليفة عمر بن عبدالعزيز باسلوب الفرزدق
Output:
 وما أصابت من الأيام جائحة  
للأصل إلا وإن جلَّت ستُجتبر  
وقد حمدتَ بأخلاق خُبرتَ بها  
وإنما يا ابن ليلى يحمد الخبر  
سخاوة من ندى مروان أعرفها  
والطعن للخيل في أكتافها زور  
ونائل لابن ليلى لو تضمنه  
سيل الفرات لأمسى وهو محتقر  

Input: كيف الحال
Output: 
عفوا لا يمكن التحدث بغير الشعر

Input:  اكتب قصيدة مدح في الخليفة عمر بن عبدالعزيز بأسلوب جرير
Output: 
 يعود الفضل منك على قريش 
وتفرج عنهم الكرب الشدادا 
وقد أمنت وحشهم برفق 
ويُعيي الناس وحشُك أن يصادا 
وتدعو الله مجتهداً ليرضى 
وتذكر في رعيتك المعادا 
وما كعب بن مامة وابن سعدي 
بأجود منك يا عمر الجوادا

Input: عطني وصفة البيتزا
Output: 
عفوا لا يمكن التحدث بغير الشعر

Input: اكتب قصيدة مدح في زين العابدين العلي بن حسين باسلوب الفرزدق
Output: 
هذا الذي تعرف البطحاء وطأته
والبيت يعرفه والحل والحرم
هذا ابن خير عباد الله كلهم 
هذا التقي النقي الطاهر العلم
هذا الذي أحمد المختار والده
صلى عليه الإله ثم جرى القلم 
هذا ابن فاطمه إن كنت جاهله 
بجده أنبياء الله قد ختم

Input: كم عدد الكواكب الشمسيه
Output:عفوا لا يمكن التحدث بغير الشعر<</SYS>>"""

        prompt = f"{prompt_input}{text_input}"
        model = Model(
            model_id=model_id,
            params=parameters,
            credentials=get_credentials(),
            project_id=project_id,
            space_id=space_id
        )
        generated_response = model.generate_text(prompt=prompt, guardrails=False)
        print(f"Generated response: {generated_response}")

        if not generated_response:
            return Response({"error": "لم يتم توليد رد."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # تحويل النص إلى صوت باستخدام ElevenLabs
        elevenlabs_api_key = get_credentials()["elevenlabs_api_key"]
        elevenlabs_voice_id = get_credentials()["elevenlabs_voice_id"]
        tts_url = f"https://api.elevenlabs.io/v1/text-to-speech/{elevenlabs_voice_id}"
        headers = {
            "Accept": "audio/mpeg",
            "Content-Type": "application/json",
            "xi-api-key": elevenlabs_api_key,
        }
        tts_body = {
            'model_id': 'eleven_turbo_v2_5',
            "text": generated_response,
            "voice_settings": {
                "stability": 0.8,
                "similarity_boost": 0.3,
                "style": 0.0,
                # "use_speaker_boost": True
            }
        }
        tts_response = requests.post(tts_url, headers=headers, json=tts_body)
        print(f"TTS response status: {tts_response.status_code}")

        if tts_response.status_code != 200:
            return Response({"error": "فشل في تحويل النص إلى صوت."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # إرجاع الصوت كملف صوتي
        audio_content = tts_response.content
        return HttpResponse(audio_content, content_type='audio/mpeg')

    except Exception as e:
        print(f"خطأ في generate_poetry_audio: {e}")
        return Response({"error": "حدث خطأ أثناء معالجة الطلب."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)