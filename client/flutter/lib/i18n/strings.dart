import 'package:slang/slang.dart';

part '_strings_en.i18n.yaml.g.dart';
part '_strings_ru.i18n.yaml.g.dart';

@StringBase(
  caseStyle: CaseStyle.CAMEL_CASE,
  pluralAuto: PluralAuto.cardinal,
)
class AppStrings extends Strings {
  static const AppStrings _instance = AppStrings();
  static AppStrings get instance => _instance;

  @override
  Map<String, Strings> get children => {};

  @override
  AppStringExtension get root => AppStringExtension();
}

extension AppStringExtension on AppStrings {
  // ─── App ───
  String get appName => 'ЧАРО';
  String get appTagline => 'Быстрый. Приватный. Мощный.';

  // ─── Auth ───
  String get login => 'Войти';
  String get register => 'Регистрация';
  String get phone => 'Телефон';
  String get password => 'Пароль';
  String get confirmPassword => 'Подтвердить пароль';
  String get forgotPassword => 'Забыли пароль?';
  String get otpVerification => 'Верификация OTP';
  String get enterOtpCode => 'Введите код из SMS';
  String get resendCode => 'Отправить снова';
  String get welcome => 'Добро пожаловать!';
  String get loginSuccess => 'Вы успешно вошли';
  String get registrationSuccess => 'Аккаунт создан';
  String get accountDeleted => 'Аккаунт удалён';

  // ─── Chat ───
  String get chats => 'Чаты';
  String get newChat => 'Новый чат';
  String get searchChats => 'Поиск чатов';
  String get noChats => 'Нет чатов';
  String get sendMessage => 'Отправить';
  String get reply => 'Ответить';
  String get forward => 'Переслать';
  String get edit => 'Редактировать';
  String get delete => 'Удалить';
  String get pin => 'Закрепить';
  String get unpin => 'Открепить';
  String get copy => 'Копировать';
  String get typing => 'печатает…';
  String get online => 'в сети';
  String get lastSeen => 'был(а) в';
  String get messageEncrypted => '🔐 Зашифровано';
  String get voiceMessage => '🎤 Голосовое';
  String get videoMessage => '📹 Видео';
  String get fileAttached => '📎 Файл';

  // ─── Calls ───
  String get calls => 'Звонки';
  String get voiceCall => 'Голосовой звонок';
  String get videoCall => 'Видеозвонок';
  String get callEnded => 'Звонок завершён';
  String get callMissed => 'Пропущенный звонок';
  String get callIncoming => 'Входящий звонок';
  String get callOutgoing => 'Исходящий звонок';
  String get mute => 'Микрофон';
  String get camera => 'Камера';
  String get speaker => 'Динамик';

  // ─── Settings ───
  String get settings => 'Настройки';
  String get appearance => 'Внешний вид';
  String get notifications => 'Уведомления';
  String get privacy => 'Приватность';
  String get network => 'Сеть';
  String get storage => 'Хранилище';
  String get language => 'Язык';
  String get about => 'О приложении';
  String get energy => 'Энергосбережение';
  String get mediaQuality => 'Качество медиа';
  String get deleteAccount => 'Удалить аккаунт';
  String get darkTheme => 'Тёмная тема';
  String get lightTheme => 'Светлая тема';
  String get fontSize => 'Размер шрифта';
  String get chatBackground => 'Обложка чата';

  // ─── Stickers ───
  String get stickers => 'Стикеры';
  String get emoji => 'Эмодзи';
  String get gif => 'GIF';
  String get stickerImport => 'Импорт стикеров';
  String get fromTelegram => 'Из Telegram';
  String get fromVk => 'Из VK';
  String get fromWhatsapp => 'Из WhatsApp';
  String get fromViber => 'Из Viber';

  // ─── Stories ───
  String get stories => 'Истории';
  String get addStory => 'Добавить историю';
  String get viewStory => 'Просмотр';

  // ─── Profile ───
  String get profile => 'Профиль';
  String get username => 'Имя пользователя';
  String get displayName => 'Отображаемое имя';
  String get bio => 'О себе';
  String get avatar => 'Аватар';
  String get changeAvatar => 'Изменить аватар';

  // ─── Errors ───
  String get errorNetwork => 'Ошибка сети';
  String get errorAuth => 'Ошибка авторизации';
  String get errorEncryption => 'Ошибка шифрования';
  String get errorUnknown => 'Неизвестная ошибка';
  String get errorRateLimit => 'Слишком много запросов';

  // ─── Accessibility ───
  String get accessibility => 'Специальные возможности';
  String get accessibilityHighContrast => 'Высокая контрастность';
  String get accessibilityLargeText => 'Увеличенный текст';
  String get accessibilityScreenReader => 'Экранный диктор';

  // ─── Privacy Policy ───
  String get privacyPolicy => 'Политика приватности';
  String get termsOfService => 'Условия использования';
  String get dataDeletion => 'Удаление данных';
  String get e2eeNotice => 'Все сообщения зашифрованы E2EE';
}
