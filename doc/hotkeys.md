# Горячие клавиши

Обозначения: `^` Ctrl, `!` Alt, `+` Shift, `#` Win.

## Общие (Levorte.Core.ahk)

| Сочетание | Действие |
|-----------|----------|
| `Ctrl + Alt + W` | Показать заголовок и класс активного окна (отладка) |
| `Ctrl + NumpadSub` | Ввод `masterkey` + Enter |
| `Ctrl + NumpadDel` | Перезагрузить скрипт |
| `Alt + Q` | Виртуальный рабочий стол влево (`Win + Ctrl + Left`) |
| `Alt + W` | Виртуальный рабочий стол вправо (`Win + Ctrl + Right`) |

## Громкость (Levorte.Media.ahk)

| Сочетание | Действие |
|-----------|----------|
| `Ctrl + NumpadDiv` | Громкость −10% (tooltip у курсора) |
| `Ctrl + NumpadMult` | Громкость +10% (tooltip у курсора) |
| `Ctrl + Alt + NumpadDiv` | Переключить mute |

## Яркость (Levorte.Brightness.ahk)

| Сочетание | Действие |
|-----------|----------|
| `Shift + NumpadDiv` | Яркость −10% |
| `Shift + NumpadMult` | Яркость +10% |
| `Ctrl + Shift + NumpadDiv` | Яркость на минимум (0%) |
| `Ctrl + Shift + NumpadMult` | Яркость на максимум (100%) |

Яркость применяется на всех мониторах (WMI + Python/DDC).

## Схемы питания (Levorte.System.ahk)

| Сочетание | Схема |
|-----------|-------|
| `Win + NumpadEnd` | Office (максимальная производительность) |
| `Win + NumpadDown` | Gaming (сбалансированная) |
| `Win + NumpadPgDn` | High performance / Silent |

При смене схемы **сохраняется текущая яркость** (не подставляется значение из профиля Windows).

## Система (Levorte.System.ahk)

| Сочетание | Действие |
|-----------|----------|
| `Ctrl + Alt + I` | Список локальных IPv4 (клик — копировать и вставить) |
| `Ctrl + Alt + O` | Публичный IP и страна (`api.myip.com`) |
| `Ctrl + Alt + U` | Окно с температурой CPU/GPU в реальном времени (обновление каждые 2 с) |
| `Win + Del` | Очистить корзину |
| `Alt + СКМ` в проводнике | Распаковать архив(ы) под курсором в подпапку с именем архива |

Поддерживаемые архивы: `.zip`, `.7z`, `.rar`, `.tar`, `.gz`, `.bz2`, `.xz` и составные расширения.

## Path of Exile (Levorte.Games.ahk)

Только при активном окне **Path of Exile**:

| Сочетание | Действие |
|-----------|----------|
| `Alt + Enter` | Вкл/выкл автонажатие Enter каждые 500 мс |
| `Enter` | То же (пока режим включён) |
| `Shift + NumpadLeft` | Импорт фильтра PoE1 из Downloads |
| `Shift + NumpadRight` | Импорт фильтра PoE2 из Downloads |
| `Shift + NumpadHome` | Импорт билда PoE1 в BuildPlanner |
| `Shift + NumpadPgUp` | Импорт билда PoE2 в BuildPlanner |

## Яндекс Музыка (Levorte.Media.ahk)

Только при открытом окне с заголовком **Яндекс**:

| Сочетание | Действие |
|-----------|----------|
| `Alt + Ctrl + D` | Лайк |
| `Alt + Ctrl + F` | Дизлайк |
| `Alt + WheelUp` | Предыдущий трек |
| `Alt + WheelDown` | Следующий трек |
| `Alt + СКМ` | Play / Pause |

## Разработка (Levorte.Dev.ahk)

| Сочетание | Действие |
|-----------|----------|
| `Ctrl + Alt + Z` | Сборка и запуск HmiView.Desktop из `C:\Work\rcs_hmi_xplat\scripts`; при повторном нажатии — остановка предыдущего запуска с теми же аргументами |

## Текстовые инструменты (Levorte.TextTools.ahk)

| Сочетание | Действие |
|-----------|----------|
| `Ctrl + NumpadAdd` | Конвертация SVG из буфера в XAML (вариант 1) |
| `Ctrl + Shift + NumpadAdd` | Конвертация SVG из буфера в XAML (вариант 2) |
