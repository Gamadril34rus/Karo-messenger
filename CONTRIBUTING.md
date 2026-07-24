# 🤝 Участие в проекте ЧАРО

Спасибо за интерес к ЧАРО! Мы рады любому вкладу.

## Как начать

1. **Форкните** репозиторий
2. **Клонируйте** ваш форк: `git clone https://github.com/your-username/charo.git`
3. **Создайте** ветку: `git checkout -b feature/amazing-feature`
4. **Реализуйте** фичу или исправление
5. **Протестируйте**: `npm test` (сервер) и `flutter test` (клиент)
6. **Закоммитьте**: `git commit -m "feat: add amazing feature"`
7. **Запушьте**: `git push origin feature/amazing-feature`
8. **Откройте** Pull Request

## Стандарты кода

### Commit Messages (Conventional Commits)

```
feat: добавить групповые видеозвонки
fix: исправить краш при отправке пустого сообщения
docs: обновить API документацию
refactor: переписать WebSocket менеджер
test: добавить тесты для AuthBloc
chore: обновить зависимости
```

### Dart/Flutter
- Следуйте [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Clean Architecture + BLoC паттерн
- 80 символов — максимальная длина строки
- Все публичные API — с документацией

### TypeScript/Node.js
- Строгий TypeScript (`strict: true`)
- ESLint + Prettier
- Все эндпоинты — с Zod-схемами валидации
- 100 символов — максимальная длина строки

## Структура PR

```
## Описание
Краткое описание изменений

## Тип изменений
- [ ] Bug fix
- [ ] Новая фича
- [ ] Breaking change
- [ ] Документация

## Как тестировать
1. Шаг 1
2. Шаг 2

## Скриншоты (если UI)
```

## Code Review

- Минимум 1 аппрув от мейнтейнера
- Все CI-проверки пройдены
- Конфликты решены

## Безопасность

Если вы нашли уязвимость — **не создавайте Issue**. Напишите на security@charo.chat.
