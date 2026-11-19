# Helix 0.9.2 — NASM язык с терминалом и первыми GUI-приложениями

Helix — экспериментальный язык с расширением `.hlx`. Языковой runtime написан на **x86-64 NASM Assembly** и не использует Python/C++ как backend. Windows runner использует NASM/Win32 API; Linux runner — GTK как платформенную оболочку для того же runtime.

Версия **0.9.2** добавляет межфайловый `bridge helix`, системный `dialog` (OK и Yes/No с записью в `cell`) и отдельную app-оболочку без терминальной панели. Также доступны native-кнопки с event ID и пять bridges к системным программам: HTML, CSS, JavaScript, C и C++. Внешние инструменты не скачиваются.

## Runner и режимы

Первая строка `.hlx` выбирает способ запуска:

```text
helix console             # стандартное окно Helix
helix console helix       # тот же runner явно
helix console windows     # настоящая системная консоль Windows
helix console linux       # обычный Linux terminal
helix app                 # отдельное окно Helix-приложения
```

GUI runner — специализированное окно запуска `.hlx`, а не замена Windows Terminal или полноценный VT/PTY shell. Он предлагает выбор файла, Run/Stop/Clear и ввод `sense` по **Enter**. Linux поддерживает перетаскивание `.hlx`.

### Настоящее графическое окно Helix app

В `helix app` графическая оболочка создаёт окно, заголовок и native buttons по декларациям в `.hlx`. Нажатие кнопки передаёт её целочисленный ID в ближайший `sense`; действие пишется обычным синтаксисом Helix:

```helix
helix app
app title "Helix — Счётчик"
app size 700 500
app button 1 "Добавить"
app button 2 "Сбросить"

cell count := 0
cell event := 0
while true
    sense event
    if event == 1
        count := count + 1
    else
        if event == 2
            count := 0
        end
    end
    pulse "Счётчик обновлён"
    pulse count
end
```

`app input` явно оставляет числовое поле ввода рядом с кнопками. Без кнопок окно показывает обычное поле для `sense`. Ограничения первого UI milestone: до шести кнопок, числовые event IDs, один app input/вывод; произвольные layouts, поля произвольных типов, рисование/canvas и мышиные события пока не реализованы. Запускаемый пример: `examples/button_app.hlx`.

## Bridges: HTML, CSS, JavaScript, C и C++

```helix
helix console
bridge html "web/index.html"
bridge css "web/style.css"
bridge js "scripts/task.js"
bridge c "native/hello.c"
bridge cpp "native/hello.cpp"
```

- `bridge html` открывает страницу системным обработчиком (обычно браузером); HTML может подключать CSS и JS через обычные `<link>`/`<script>`.
- `bridge css` открывает `.css` системным приложением, связанным с этим типом файла. CSS сам по себе не запускается.
- `bridge js` запускает `node` / `node.exe`.
- `bridge c` и `bridge cpp` запускают системные `cc`/`gcc` и `c++`/`g++`: компилируют исходный файл во временную папку, запускают результат и удаляют его.

Инструменты **не включены** и не скачиваются. HTML/CSS требуют системной ассоциации; JavaScript — установленного Node.js; для C/C++ нужен компилятор, доступный через `PATH`. Если tool отсутствует, Helix сообщит об ошибке. На Windows исходник/путь должен быть допустим для Win32 command line. Вызов external bridge исполняет пользовательский код с правами текущего пользователя; запускай только доверенные файлы.

## Краткий язык

```helix
helix console
cell total := 0
cell i := 1
while i <= 5
    total := total + i
    i := i + 1
end
pulse "Сумма:"
pulse total
pulse logical_and(true, is_prime(13))
```

Доступны signed 64-bit integer cells, арифметика `+ - * / %`, сравнения, `pulse`, числовой `sense`, `if/else/end`, `while/end`, standalone truthy/falsy conditions, файловые команды и 53 числовых built-ins. Комментарии начинаются с `#` на отдельной строке. Блоки закрываются словом `end`.

```helix
helix console
cell id := 1
cell score := -42
spawn dir "logs_{id}" .
spawn file "session_{id}.txt" "logs_{id}" "score={score}\n"
append file "logs_{id}/session_{id}.txt" "id={id}\n"
pulse file_exists("logs_{id}/session_{id}.txt")
read file "logs_{id}/session_{id}.txt"
pulse random(1, 100)
pulse time_ms()
pulse sleep_ms(25)
```

`spawn file` не перезаписывает существующий файл; `append file` дозаписывает текст; `read file` читает текстовый UTF-8; `remove file` удаляет один указанный файл. `{cell}` подставляет числовую ячейку только в аргументах файловых команд. Файловые операции имеют обычные права пользователя и не являются sandbox.

## Оборудование и ресурсы

Доступны `cpu_count()`, `memory_total_mb()`, `memory_available_mb()`, `gpu_count()`, `limit_cpu(n)` и `limit_memory_mb(n)`. Без явного вызова лимитов ресурсы остаются под контролем ОС. GPU-функция только перечисляет адаптеры; GPU kernels и VRAM limits не реализованы. См. `examples/hardware.hlx`.

## Примеры и документы

- `examples/hello.hlx` — первое сообщение и выражения.
- `examples/desktop_app.hlx` — отдельное окно и `sense`.
- `examples/button_app.hlx` — native app buttons и event actions.
- `examples/calculator.hlx` — интерактивный калькулятор.
- `examples/filesystem.hlx` — файлы и подстановки ячеек.
- `examples/time_random.hlx` — время, задержки, случайные числа.
- `examples/hardware.hlx` — CPU/RAM/GPU query и resource limits.
- [Руководство начинающего](HELIX_0.9.2_GUIDE_RU.txt).
- [Строгая спецификация для ИИ](HELIX_AI_INSTRUCTIONS_RU.txt).
- [Что изменилось в 0.9.2](CHANGELOG_RU.txt).
- [Сборка из исходников](BUILDING_RU.txt).
- [Оригинальные рекомендации Gemini](GEMINI_RECOMMENDATIONS_RU.txt).

## Установка и запуск

### Windows

Запусти `Helix-Setup-0.9.2-x64.exe`. Установщик запрашивает подтверждение Windows UAC для установки в `Program Files`, создаёт ярлык и ассоциацию `.hlx`. Не запускать установщик молча от администратора: запрос elevation выполняет Windows.

### Linux AppImage

```bash
chmod +x Helix-0.9.2-x86_64.AppImage
./Helix-0.9.2-x86_64.AppImage
```

Интеграция только для текущего Linux-пользователя, без `sudo`:

```bash
./Helix-0.9.2-x86_64.AppImage --install
~/Applications/Helix-0.9.2-x86_64.AppImage --uninstall
```

AppImage копируется в `~/Applications`, desktop entry и icon — в пользовательские каталоги. Системные пакеты, `/usr` и глобальные file associations не изменяются. Можно открыть `.hlx` напрямую, передав его путь аргументом. `helix console linux` при прямом CLI-вызове использует системный терминал.

## Разработка и проверка

На Linux нужны NASM, GCC, GTK3 development files и Make; `make test` запускает engine и bridge regressions. `make gui-test` дополнительно требует Xvfb/xdotool. Для Windows cross-build нужны MinGW-w64 и NSIS; сборка AppImage загружает инструменты linuxdeploy/AppImageKit.

```bash
make test
make gui-test
make windows
make installer
make appimage
```

В этой среде выполнены Linux language/bridge tests, GTK GUI tests под Xvfb, а Windows x64 engine/GUI cross-compiled и linked. Целевые CachyOS и Debian 13/14 отдельно на физических компьютерах не запускались. Windows GUI требует практической проверки на Windows.

## Ограничения

Helix 0.9.2 — ранняя экспериментальная версия. Нет пользовательских функций, массивов/коллекций, строковых ячеек и конкатенации, дробных чисел, `for/break/continue`, модулей/import, классов, исключений, полноценного shell/PTY, указателей, GPU-вычислений и VRAM API. `bridge` — простой запуск системной программы, не встроенные реализации этих языков и не sandbox.
