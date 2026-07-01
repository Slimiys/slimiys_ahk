#!/usr/bin/env python3
"""
Скрипт для автоматического изменения яркости в зависимости от времени суток.
"""

import sys
from datetime import datetime, time
import subprocess

# Константы времени
DAY_START_HOUR = 8
DAY_START_MINUTE = 0
DAY_END_HOUR = 19
DAY_END_MINUTE = 0

# Константы яркости
DAY_BRIGHTNESS = 100
NIGHT_BRIGHTNESS = 0


def set_brightness(percentage):
    """
    Устанавливает яркость экрана.
    """
    try:
        import screen_brightness_control as sbc
        success = False

        # 1) Встроенные панели (обычно ноутбук): backend WMI.
        try:
            wmi_monitors = sbc.list_monitors_info(method="wmi")
            for monitor_index in range(len(wmi_monitors)):
                try:
                    sbc.set_brightness(percentage, display=monitor_index, method="wmi")
                    success = True
                except Exception:
                    pass
        except Exception:
            pass

        # 2) Внешние мониторы: backend VCP (DDC/CI).
        try:
            vcp_monitors = sbc.list_monitors_info(method="vcp")
            for monitor_index in range(len(vcp_monitors)):
                try:
                    sbc.set_brightness(percentage, display=monitor_index, method="vcp")
                    success = True
                except Exception:
                    pass
        except Exception:
            pass

        # 3) Универсальная попытка "на всё сразу".
        if not success:
            try:
                sbc.set_brightness(percentage)
                success = True
            except Exception:
                success = False

        if success:
            print(f"Яркость установлена на {percentage}%")
            return True

    except ImportError:
        pass
    except Exception:
        pass

    try:
        # Fallback на PowerShell
        script = f"""
        $monitors = Get-WmiObject WmiMonitorBrightnessMethods -Namespace root\\wmi
        foreach ($monitor in $monitors) {{
            $monitor.WmiSetBrightness(1, {percentage})
        }}
        """
        result = subprocess.run(
            ["powershell", "-Command", script],
            capture_output=True,
            text=True,
            shell=True,
        )
        if result.returncode == 0:
            print(f"Яркость установлена на {percentage}%")
            return True

        return False
    except Exception:
        return False


def get_current_time():
    """
    Получает текущее время.
    """
    return datetime.now().time()


def should_use_day_brightness():
    """
    Определяет, нужно ли использовать дневную яркость.
    Дневное время: 8:00 - 19:00.
    """
    current_time = get_current_time()
    day_start = time(DAY_START_HOUR, DAY_START_MINUTE)
    day_end = time(DAY_END_HOUR, DAY_END_MINUTE)
    return day_start <= current_time <= day_end


def auto_set_brightness():
    """
    Автоматически устанавливает яркость в зависимости от времени.
    """
    current_time = get_current_time()

    if should_use_day_brightness():
        # Дневное время: яркость 100%
        brightness = DAY_BRIGHTNESS
        period = "дневное"
    else:
        # Ночное время: яркость 0%
        brightness = NIGHT_BRIGHTNESS
        period = "ночное"

    print(f"Текущее время: {current_time}, период: {period}, яркость: {brightness}%")
    return set_brightness(brightness)


def print_usage():
    print("Использование:")
    print("  python auto_brightness.py auto   # Автоматический режим")
    print(f"  python auto_brightness.py day    # Дневная яркость ({DAY_BRIGHTNESS}%)")
    print(f"  python auto_brightness.py night  # Ночная яркость ({NIGHT_BRIGHTNESS}%)")
    print("  python auto_brightness.py <0-100>  # Установить яркость в процентах")


def main():
    """
    Основная функция.
    """
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg == "day":
            set_brightness(DAY_BRIGHTNESS)
        elif arg == "night":
            set_brightness(NIGHT_BRIGHTNESS)
        elif arg == "auto":
            auto_set_brightness()
        else:
            try:
                brightness_value = int(arg)
                if 0 <= brightness_value <= 100:
                    set_brightness(brightness_value)
                else:
                    print(
                        f"Ошибка: значение яркости должно быть от 0 до 100, получено: {brightness_value}"
                    )
                    print_usage()
            except ValueError:
                print_usage()
    else:
        # По умолчанию - автоматический режим
        auto_set_brightness()


if __name__ == "__main__":
    main()
