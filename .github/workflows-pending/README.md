# Исправленные CI-workflows

Токет агента Arena не имеет права `workflows`, поэтому файлы нельзя закоммитить
прямо в `.github/workflows/`. Чтобы активировать исправленные сборки:

1. Скопируйте `main.yml` и `release.yml` в `.github/workflows/`
   (заменив существующие) — через веб-интерфейс GitHub:
   откройте файл → ✏️ Edit → скопируйте содержимое из `workflows-pending`.
2. Или локально:
   ```bash
   cp .github/workflows-pending/main.yml .github/workflows/main.yml
   cp .github/workflows-pending/release.yml .github/workflows/release.yml
   git commit -am "ci: activate fixed workflows" && git push
   ```
3. Или переподключите GitHub в Arena с правом `workflows` — тогда агент
   запушит и доведёт сборки до зелёных сам.

После активации: пуш в `main` собирает все 6 платформ и деплоит Web на
GitHub Pages; тег `v*` создаёт Release с APK/ZIP/TAR.GZ.
