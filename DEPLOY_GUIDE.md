# 🚀 ЧАРО — Бесплатный деплой (0₽ навсегда)

## Вариант 1. Glitch.com — проще всего, 0₽

**3 клика и готово:**

1. Открой эту ссылку в браузере:
   👉 **https://glitch.com/edit/#!/import/github/Gamadril34rus/Karo-messenger**

2. Glitch импортирует проект автоматически

3. В файле `.env` вставь:
```
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
JWT_ACCESS_SECRET=1e1d9d626681ffaaf9f5e08223612db11e22c969e66cdc516e9d922531a4de81
JWT_REFRESH_SECRET=9dc386c8b6db05de0ae6ec86135c74c4c5ad32b1e775644dd8eb2574eb252b60
CORS_ORIGINS=*
LOG_LEVEL=info
```

4. Готово! URL: `https://твоё-имя.glitch.me`

**Минус:** спит через 5 мин, первый запрос ~10 сек. Для теста ок.

---

## Вариант 2. Локально на твоём ПК — 0₽

Если у тебя Windows/Linux/Mac:

```bash
# Установить Node.js с nodejs.org (LTS версию)
# Потом в терминале:
git clone https://github.com/Gamadril34rus/Karo-messenger
cd Karo-messenger/server
npm ci
npx prisma generate
npx prisma migrate deploy
npm run build
npm start
```

Сервер будет на **http://localhost:3000**

---

## Вариант 3. Android-телефон — Termux (0₽)

Запустить сервер прямо на телефоне:

1. Установи **Termux** из F-Droid
2. В Termux:
```
pkg install nodejs git
git clone https://github.com/Gamadril34rus/Karo-messenger
cd Karo-messenger/server
npm ci && npx prisma generate && npm run build
npm start
```

---

## 💰 Все варианты: 0₽
