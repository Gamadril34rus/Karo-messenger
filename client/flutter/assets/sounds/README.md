# Звуки ЧАРО (ICQ-inspired)

Все звуки вдохновлены классическими звуками ICQ — мессенджера,
который задал стандарт звуков уведомлений в 1990-х и 2000-х.

ЧАРО сохраняет дух ICQ, но с современным качеством звука.

## Файлы звуков

### icq_message.wav — Входящее сообщение
- **Вдохновлено:** Классический ICQ "Uh-oh!" (incoming message sound)
- **Описание:** Короткий, дружелюбный "uh-oh" — 2 нотки, слегка падающие
- **Длительность:** ~0.5 секунд
- **Формат:** WAV, 44100 Hz, 16-bit, mono
- **Параметры для генерации:**
  - Частоты: 880 Hz → 660 Hz (падающий тон)
  - Длительность каждой нотки: 0.15s, pause: 0.05s
  - Тип волны: sine + slight triangle для "живости"
  - Amplitude envelope: quick attack, short decay

### icq_send.wav — Отправка сообщения
- **Вдохновлено:** ICQ outgoing message chirp
- **Описание:** Мягкий восходящий "пик" — подтверждение отправки
- **Длительность:** ~0.3 секунд
- **Формат:** WAV, 44100 Hz, 16-bit, mono
- **Параметры для генерации:**
  - Частоты: 660 Hz → 880 Hz (восходящий тон)
  - Длительность: 0.2s
  - Тип волны: sine
  - Amplitude envelope: quick attack, medium decay

### icq_call.wav — Входящий звонок
- **Вдохновлено:** ICQ incoming call ringtone
- **Описание:** Ритмичный повторяющийся паттерн — 3 нотки ascending
- **Длительность:** ~2.0 секунд (loop)
- **Формат:** WAV, 44100 Hz, 16-bit, mono
- **Параметры для генерации:**
  - Частоты: 440 Hz, 550 Hz, 660 Hz (ascending triad)
  - Длительность каждой: 0.2s, pause: 0.15s
  - Паттерн повторяется 2 раза
  - Тип волны: sine with slight square for urgency
  - Loop для продолжительности звонка

### icq_online.wav — Контакт появился онлайн
- **Вдохновлено:** ICQ "door open" sound (user came online)
- **Описание:** Приятный восходящий "блинк" — радостный, но не intrusive
- **Длительность:** ~0.4 секунд
- **Формат:** WAV, 44100 Hz, 16-bit, mono
- **Параметры для генерации:**
  - Частоты: 440 Hz → 880 Hz (быстрый восходящий тон)
  - Длительность: 0.3s
  - Тип волны: sine
  - Amplitude envelope: medium attack, quick decay

### icq_system.wav — Системное уведомление
- **Вдохновлено:** ICQ system notification
- **Описание:** Нейтральный "блинк" — системное, не эмоциональное
- **Длительность:** ~0.3 секунд
- **Формат:** WAV, 44100 Hz, 16-bit, mono
- **Параметры для генерации:**
  - Частоты: 550 Hz (flat tone)
  - Длительность: 0.2s
  - Тип волны: sine
  - Amplitude envelope: quick attack, quick decay

## Генерация WAV файлов

Для генерации реальных WAV файлов можно использовать Python:
```python
import numpy as np
import wave
import struct

def generate_tone(freq, duration, sample_rate=44100, wave_type='sine'):
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    if wave_type == 'sine':
        tone = np.sin(2 * np.pi * freq * t)
    elif wave_type == 'triangle':
        tone = 2 * np.abs(2 * (t * freq - np.floor(t * freq + 0.5))) - 1
    elif wave_type == 'square':
        tone = np.sign(np.sin(2 * np.pi * freq * t))
    return tone

def save_wav(filename, samples, sample_rate=44100):
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        for sample in samples:
            wav.writeframes(struct.pack('<h', int(sample * 32767)))

# icq_message.wav (Uh-oh!)
tone1 = generate_tone(880, 0.15)
pause = np.zeros(int(44100 * 0.05))
tone2 = generate_tone(660, 0.15)
envelope1 = np.concatenate([np.linspace(0, 1, 100), np.linspace(1, 0.3, len(tone1)-100)])
envelope2 = np.concatenate([np.linspace(0, 1, 100), np.linspace(1, 0, len(tone2)-100)])
uh_oh = np.concatenate([tone1 * envelope1, pause, tone2 * envelope2])
save_wav('icq_message.wav', uh_oh)
```

## Местоположение в проекте
`client/flutter/assets/sounds/`

## pubspec.yaml
```yaml
assets:
  - assets/sounds/
```
