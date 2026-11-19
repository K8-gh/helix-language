#define _GNU_SOURCE
#include <gtk/gtk.h>
#include <glib/gstdio.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define VERSION "0.9.2"
#define MAX_APP_BUTTONS 6

typedef struct App App;
typedef struct {
    App *app;
    gboolean is_stderr;
    GByteArray *pending_utf8;
    GByteArray *dialog_packet;
    gboolean collecting_dialog;
} PipeWatch;

struct App {
    GtkWidget *window;
    GtkWidget *path_entry;
    GtkWidget *output_view;
    GtkWidget *output_scrolled;
    GtkWidget *input_entry;
    GtkWidget *input_row;
    GtkWidget *input_label;
    GtkWidget *toolbar;
    GtkWidget *run_button;
    GtkWidget *stop_button;
    GtkWidget *send_button;
    GtkWidget *browse_button;
    GtkWidget *clear_button;
    GtkWidget *status_label;
    GtkWidget *app_controls;
    GtkWidget *app_surface;
    GtkWidget *app_button_box;
    GtkWidget *app_buttons[MAX_APP_BUTTONS];
    gint app_button_ids[MAX_APP_BUTTONS];
    guint app_button_count;
    GPid pid;
    gint input_fd;
    gboolean child_exited;
    gboolean stdout_open;
    gboolean stderr_open;
    gboolean finish_written;
    gboolean app_mode;
    gboolean app_has_input;
};

static void append_text_tag(App *app, const gchar *text, const gchar *tag_name)
{
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->output_view));
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(buffer, &end);
    GtkTextTag *tag = tag_name ? gtk_text_tag_table_lookup(gtk_text_buffer_get_tag_table(buffer), tag_name) : NULL;
    if (tag)
        gtk_text_buffer_insert_with_tags(buffer, &end, text, -1, tag, NULL);
    else
        gtk_text_buffer_insert(buffer, &end, text, -1);
    gtk_text_view_scroll_to_iter(GTK_TEXT_VIEW(app->output_view), &end, 0.0, FALSE, 0.0, 1.0);
}

static void append_text(App *app, const gchar *text)
{
    append_text_tag(app, text, NULL);
}

static void set_status(App *app, const gchar *text)
{
    if (app->status_label)
        gtk_label_set_text(GTK_LABEL(app->status_label), text);
}

static void maybe_finish(App *app)
{
    if (app->child_exited && !app->stdout_open && !app->stderr_open && !app->finish_written) {
        app->finish_written = TRUE;
        if (!app->app_mode)
            append_text(app, "\n[программа завершена]\n");
        gtk_widget_set_sensitive(app->run_button, TRUE);
        gtk_widget_set_sensitive(app->stop_button, FALSE);
        gtk_widget_set_sensitive(app->browse_button, TRUE);
        gtk_widget_set_sensitive(app->input_entry, FALSE);
        gtk_widget_set_sensitive(app->send_button, FALSE);
        for (guint i = 0; i < app->app_button_count; ++i)
            gtk_widget_set_sensitive(app->app_buttons[i], FALSE);
    }
}

static void close_stream(App *app, gboolean is_stderr)
{
    if (is_stderr)
        app->stderr_open = FALSE;
    else
        app->stdout_open = FALSE;
    maybe_finish(app);
}

static gsize complete_utf8_prefix(const guint8 *bytes, gsize length)
{
    gsize offset = 0;
    while (offset < length) {
        guint8 lead = bytes[offset];
        gsize width = lead < 0x80 ? 1 :
                      (lead >= 0xC2 && lead <= 0xDF) ? 2 :
                      (lead >= 0xE0 && lead <= 0xEF) ? 3 :
                      (lead >= 0xF0 && lead <= 0xF4) ? 4 : 1;
        if (width > length - offset)
            break;
        gboolean continuation_ok = TRUE;
        for (gsize i = 1; i < width; ++i) {
            if ((bytes[offset + i] & 0xC0) != 0x80) {
                continuation_ok = FALSE;
                break;
            }
        }
        offset += continuation_ok ? width : 1;
    }
    return offset;
}

static void append_pipe_bytes(PipeWatch *watch, const gchar *bytes, gsize length, gboolean flush)
{
    if (length)
        g_byte_array_append(watch->pending_utf8, (const guint8 *)bytes, (guint)length);
    gsize ready = flush ? watch->pending_utf8->len :
                  complete_utf8_prefix(watch->pending_utf8->data, watch->pending_utf8->len);
    if (ready) {
        gchar *valid = g_utf8_make_valid((const gchar *)watch->pending_utf8->data, (gssize)ready);
        if (!watch->app->app_mode)
            append_text_tag(watch->app, valid, watch->is_stderr ? "stderr" : "stdout");
        g_free(valid);
        g_byte_array_remove_range(watch->pending_utf8, 0, (guint)ready);
    }
}

static gchar *decode_hex_utf8(const gchar *hex)
{
    gsize length = strlen(hex);
    if (length & 1)
        return NULL;
    gchar *decoded = g_malloc(length / 2 + 1);
    for (gsize i = 0; i < length; i += 2) {
        gint hi = g_ascii_xdigit_value(hex[i]);
        gint lo = g_ascii_xdigit_value(hex[i + 1]);
        if (hi < 0 || lo < 0) {
            g_free(decoded);
            return NULL;
        }
        decoded[i / 2] = (gchar)((hi << 4) | lo);
    }
    decoded[length / 2] = '\0';
    if (!g_utf8_validate(decoded, -1, NULL)) {
        gchar *valid = g_utf8_make_valid(decoded, -1);
        g_free(decoded);
        return valid;
    }
    return decoded;
}

static void handle_dialog_packet(App *app, const gchar *packet)
{
    if (!g_str_has_prefix(packet, "HELIX_DIALOG\t"))
        return;
    gchar **parts = g_strsplit(packet, "\t", 4);
    if (!parts[0] || !parts[1] || !parts[2] || !parts[3] ||
        (strcmp(parts[1], "I") != 0 && strcmp(parts[1], "Q") != 0)) {
        g_strfreev(parts);
        return;
    }
    gchar *title = decode_hex_utf8(parts[2]);
    gchar *message = decode_hex_utf8(parts[3]);
    if (!title || !message) {
        g_free(title);
        g_free(message);
        g_strfreev(parts);
        return;
    }
    gboolean question = strcmp(parts[1], "Q") == 0;
    GtkWidget *dialog = gtk_message_dialog_new(GTK_WINDOW(app->window), GTK_DIALOG_MODAL,
        question ? GTK_MESSAGE_ERROR : GTK_MESSAGE_INFO,
        question ? GTK_BUTTONS_YES_NO : GTK_BUTTONS_OK, "%s", message);
    gtk_window_set_title(GTK_WINDOW(dialog), title);
    gtk_window_set_destroy_with_parent(GTK_WINDOW(dialog), TRUE);
    gint result = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);

    const gchar *response = question && result == GTK_RESPONSE_YES ? "1\n" : "0\n";
    if (app->input_fd >= 0) {
        gsize left = 2;
        const gchar *cursor = response;
        while (left) {
            ssize_t count = write(app->input_fd, cursor, left);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                break;
            cursor += count;
            left -= (gsize)count;
        }
    }
    g_free(title);
    g_free(message);
    g_strfreev(parts);
}

static void process_pipe_bytes(PipeWatch *watch, const gchar *bytes, gsize length, gboolean flush)
{
    if (watch->is_stderr) {
        append_pipe_bytes(watch, bytes, length, flush);
        return;
    }
    GByteArray *plain = g_byte_array_new();
    for (gsize i = 0; i < length; ++i) {
        guint8 byte = (guint8)bytes[i];
        if (watch->collecting_dialog) {
            if (byte == '\n') {
                g_byte_array_append(watch->dialog_packet, (const guint8 *)"", 1);
                watch->dialog_packet->data[watch->dialog_packet->len - 1] = '\0';
                handle_dialog_packet(watch->app, (const gchar *)watch->dialog_packet->data);
                g_byte_array_set_size(watch->dialog_packet, 0);
                watch->collecting_dialog = FALSE;
            } else if (watch->dialog_packet->len < 20000) {
                g_byte_array_append(watch->dialog_packet, &byte, 1);
            } else {
                g_byte_array_set_size(watch->dialog_packet, 0);
                watch->collecting_dialog = FALSE;
            }
        } else if (byte == 0x1e) {
            if (plain->len)
                append_pipe_bytes(watch, (const gchar *)plain->data, plain->len, FALSE);
            g_byte_array_set_size(plain, 0);
            watch->collecting_dialog = TRUE;
            g_byte_array_set_size(watch->dialog_packet, 0);
        } else {
            g_byte_array_append(plain, &byte, 1);
        }
    }
    if (plain->len || flush)
        append_pipe_bytes(watch, (const gchar *)plain->data, plain->len, flush);
    g_byte_array_unref(plain);
}

static gboolean on_pipe_ready(GIOChannel *channel, GIOCondition condition, gpointer data)
{
    PipeWatch *watch = data;
    App *app = watch->app;
    gchar buffer[8192];
    gboolean close_pipe = FALSE;

    for (;;) {
        gsize bytes_read = 0;
        GError *error = NULL;
        GIOStatus status = g_io_channel_read_chars(channel, buffer, sizeof(buffer), &bytes_read, &error);
        if (bytes_read > 0) {
            process_pipe_bytes(watch, buffer, bytes_read, FALSE);
            continue;
        }
        if (status == G_IO_STATUS_EOF) {
            close_pipe = TRUE;
            break;
        }
        if (status == G_IO_STATUS_ERROR) {
            if (error) {
                gchar *message = g_strdup_printf("\n[ошибка чтения вывода: %s]\n", error->message);
                append_text(app, message);
                g_free(message);
                g_error_free(error);
            }
            close_pipe = TRUE;
            break;
        }
        if (error)
            g_error_free(error);
        if (status == G_IO_STATUS_AGAIN) {
            close_pipe = (condition & (G_IO_HUP | G_IO_ERR | G_IO_NVAL)) != 0;
            break;
        }
        break;
    }

    if (close_pipe) {
        process_pipe_bytes(watch, NULL, 0, TRUE);
        g_io_channel_shutdown(channel, FALSE, NULL);
        g_io_channel_unref(channel);
        close_stream(app, watch->is_stderr);
        g_byte_array_unref(watch->pending_utf8);
        g_byte_array_unref(watch->dialog_packet);
        g_free(watch);
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static void install_pipe_watch(App *app, gint fd, gboolean is_stderr)
{
    GIOChannel *channel = g_io_channel_unix_new(fd);
    g_io_channel_set_encoding(channel, NULL, NULL);
    g_io_channel_set_buffered(channel, FALSE);
    g_io_channel_set_close_on_unref(channel, TRUE);
    g_io_channel_set_flags(channel, G_IO_FLAG_NONBLOCK, NULL);
    PipeWatch *watch = g_new0(PipeWatch, 1);
    watch->app = app;
    watch->is_stderr = is_stderr;
    watch->pending_utf8 = g_byte_array_new();
    watch->dialog_packet = g_byte_array_new();
    g_io_add_watch(channel, G_IO_IN | G_IO_HUP | G_IO_ERR | G_IO_NVAL, on_pipe_ready, watch);
}

static void on_child_exit(GPid pid, gint status, gpointer data)
{
    App *app = data;
    if (app->pid == pid)
        app->pid = 0;
    app->child_exited = TRUE;
    if (app->input_fd >= 0) {
        close(app->input_fd);
        app->input_fd = -1;
    }
    g_spawn_close_pid(pid);
    if (WIFEXITED(status)) {
        gchar *summary = g_strdup_printf("Готово · код завершения %d", WEXITSTATUS(status));
        set_status(app, summary);
        g_free(summary);
    } else if (WIFSIGNALED(status)) {
        gchar *summary = g_strdup_printf("Остановлено · сигнал %d", WTERMSIG(status));
        set_status(app, summary);
        g_free(summary);
    }
    maybe_finish(app);
}

static gboolean uses_linux_console(const gchar *path)
{
    FILE *file = fopen(path, "rb");
    if (!file)
        return FALSE;
    gchar line[128];
    gboolean match = FALSE;
    if (fgets(line, sizeof(line), file)) {
        line[strcspn(line, "\r\n")] = '\0';
        match = strcmp(line, "helix console linux") == 0;
    }
    fclose(file);
    return match;
}

static gboolean uses_helix_app(const gchar *path)
{
    FILE *file = fopen(path, "rb");
    if (!file)
        return FALSE;
    gchar line[128];
    gboolean match = FALSE;
    if (fgets(line, sizeof(line), file)) {
        line[strcspn(line, "\r\n")] = '\0';
        match = strcmp(line, "helix app") == 0;
    }
    fclose(file);
    return match;
}

static void on_app_button_clicked(GtkButton *button, gpointer data);

static gchar *parse_quoted_value(const gchar *text)
{
    if (!text || *text != '"')
        return NULL;
    GString *value = g_string_new(NULL);
    const gchar *p = text + 1;
    while (*p && *p != '\n' && *p != '\r') {
        if (*p == '"') {
            ++p;
            while (g_ascii_isspace(*p))
                ++p;
            if (*p) {
                g_string_free(value, TRUE);
                return NULL;
            }
            return g_string_free(value, FALSE);
        }
        if (*p == '\\' && (p[1] == '"' || p[1] == '\\'))
            ++p;
        g_string_append_c(value, *p++);
    }
    g_string_free(value, TRUE);
    return NULL;
}

static void parse_app_declarations(App *app, const gchar *source_path)
{
    gchar *contents = NULL;
    gsize length = 0;
    GError *error = NULL;
    if (!g_file_get_contents(source_path, &contents, &length, &error)) {
        set_status(app, error ? error->message : "Не удалось прочитать app source");
        g_clear_error(&error);
        return;
    }
    if (!g_utf8_validate(contents, (gssize)length, NULL)) {
        set_status(app, "App source должен быть UTF-8");
        g_free(contents);
        return;
    }

    gchar *custom_title = NULL;
    gchar **lines = g_strsplit(contents, "\n", -1);
    for (guint i = 0; lines[i]; ++i) {
        gchar *line = g_strstrip(lines[i]);
        if (g_str_has_prefix(line, "app title ")) {
            gchar *value = parse_quoted_value(line + strlen("app title "));
            if (value && *value) {
                g_free(custom_title);
                custom_title = value;
            } else {
                g_free(value);
            }
        } else if (g_str_has_prefix(line, "app size ")) {
            gchar *end = NULL;
            gint64 width = g_ascii_strtoll(line + strlen("app size "), &end, 10);
            gint64 height = end ? g_ascii_strtoll(end, &end, 10) : 0;
            while (end && g_ascii_isspace(*end))
                ++end;
            if (width >= 480 && width <= 1600 && height >= 320 && height <= 1200 && end && !*end)
                gtk_window_resize(GTK_WINDOW(app->window), (gint)width, (gint)height);
        } else if (g_str_has_prefix(line, "app input") &&
                   (line[strlen("app input")] == '\0' || g_ascii_isspace(line[strlen("app input")]))) {
            app->app_has_input = TRUE;
        } else if (g_str_has_prefix(line, "app button ")) {
            gchar *end = NULL;
            gint64 id = g_ascii_strtoll(line + strlen("app button "), &end, 10);
            if (!end || end == line + strlen("app button ") || id < 1 || id > 9999 || app->app_button_count >= MAX_APP_BUTTONS)
                continue;
            while (g_ascii_isspace(*end))
                ++end;
            gchar *caption = parse_quoted_value(end);
            if (!caption || !*caption) {
                g_free(caption);
                continue;
            }
            gboolean duplicate = FALSE;
            for (guint j = 0; j < app->app_button_count; ++j)
                duplicate |= app->app_button_ids[j] == (gint)id;
            if (duplicate) {
                g_free(caption);
                continue;
            }
            GtkWidget *button = gtk_button_new_with_label(caption);
            gtk_widget_set_size_request(button, 120, 38);
            g_object_set_data(G_OBJECT(button), "helix-app", app);
            g_signal_connect(button, "clicked", G_CALLBACK(on_app_button_clicked), GINT_TO_POINTER((gint)id));
            gtk_box_pack_start(GTK_BOX(app->app_button_box), button, FALSE, FALSE, 0);
            app->app_buttons[app->app_button_count] = button;
            app->app_button_ids[app->app_button_count] = (gint)id;
            ++app->app_button_count;
            g_free(caption);
        }
    }
    if (custom_title) {
        gtk_window_set_title(GTK_WINDOW(app->window), custom_title);
        g_free(custom_title);
    }
    g_strfreev(lines);
    g_free(contents);
}

static void enter_app_window(App *app, const gchar *source_path)
{
    if (app->app_mode)
        return;
    app->app_mode = TRUE;
    gchar *name = g_path_get_basename(source_path);
    gchar *title = g_strdup_printf("%s — Helix App", name);
    gtk_window_set_title(GTK_WINDOW(app->window), title);
    gtk_window_resize(GTK_WINDOW(app->window), 820, 600);
    parse_app_declarations(app, source_path);
    gtk_widget_hide(app->toolbar);
    gtk_widget_hide(app->clear_button);
    gtk_widget_hide(app->status_label);
    gtk_widget_hide(app->output_scrolled);
    GtkWidget *input_row = g_object_ref(app->input_row);
    GtkWidget *input_parent = gtk_widget_get_parent(input_row);
    if (input_parent)
        gtk_container_remove(GTK_CONTAINER(input_parent), input_row);
    gtk_box_pack_end(GTK_BOX(app->app_surface), input_row, FALSE, FALSE, 0);
    g_object_unref(input_row);
    gtk_widget_show(app->app_surface);
    if (app->app_button_count)
        gtk_widget_show_all(app->app_controls);
    else
        gtk_widget_hide(app->app_controls);
    if (app->app_button_count && !app->app_has_input)
        gtk_widget_hide(app->input_row);
    else
        gtk_widget_show_all(app->input_row);
    gtk_label_set_text(GTK_LABEL(app->input_label), app->app_button_count ? "Действие / ввод:" : "Ввод приложения:");
    set_status(app, "Приложение запущено");
    g_free(title);
    g_free(name);
}

static void on_clear_clicked(GtkButton *button, gpointer data)
{
    (void)button;
    App *app = data;
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->output_view));
    gtk_text_buffer_set_text(buffer, "", 0);
    set_status(app, "Вывод очищен");
}

static const gchar *core_path(void)
{
    const gchar *configured = g_getenv("HELIX_CORE");
    if (configured && *configured)
        return configured;
    return "./dist/helix-linux-x86_64";
}

static void report_error(App *app, const gchar *prefix, const gchar *detail)
{
    gchar *message = g_strdup_printf("%s%s%s\n", prefix, detail ? ": " : "", detail ? detail : "");
    append_text_tag(app, message, "stderr");
    set_status(app, "Ошибка");
    g_free(message);
}

static void run_program(App *app)
{
    if (app->pid > 0) {
        report_error(app, "Программа уже выполняется", NULL);
        return;
    }

    const gchar *entry_path = gtk_entry_get_text(GTK_ENTRY(app->path_entry));
    if (!entry_path || !*entry_path) {
        report_error(app, "Сначала выберите файл .hlx", NULL);
        return;
    }
    gchar *path = g_canonicalize_filename(entry_path, NULL);
    if (!g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
        report_error(app, "Файл не найден", path);
        g_free(path);
        return;
    }
    gboolean requested_app = uses_helix_app(path);

    gchar *engine = g_canonicalize_filename(core_path(), NULL);
    if (!g_file_test(engine, G_FILE_TEST_IS_EXECUTABLE)) {
        report_error(app, "Не найден runtime Helix", engine);
        g_free(engine);
        g_free(path);
        return;
    }

    if (uses_linux_console(path)) {
        if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO)) {
            report_error(app, "Режим helix console linux требует запуска AppImage из Linux-терминала", NULL);
            report_error(app, "Подсказка", "./Helix-0.9.1-x86_64.AppImage program.hlx");
            g_free(engine);
            g_free(path);
            return;
        }
        gchar *argv[] = {(gchar *)engine, (gchar *)path, NULL};
        GError *error = NULL;
        GPid pid = 0;
        if (!g_spawn_async(NULL, argv, NULL,
                           G_SPAWN_DO_NOT_REAP_CHILD | G_SPAWN_CHILD_INHERITS_STDIN,
                           NULL, NULL, &pid, &error)) {
            report_error(app, "Не удалось открыть системную консоль", error ? error->message : NULL);
            g_clear_error(&error);
            g_free(engine);
            g_free(path);
            return;
        }
        g_free(engine);
        g_free(path);
        gtk_main_quit();
        return;
    }

    gchar *argv[] = {(gchar *)engine, (gchar *)path, NULL};
    gint input_fd = -1, output_fd = -1, error_fd = -1;
    GError *error = NULL;
    gchar *directory = g_path_get_dirname(path);
    gchar **child_env = g_get_environ();
    if (requested_app)
        child_env = g_environ_setenv(child_env, "HELIX_DIALOG_HOST", "1", TRUE);
    gboolean spawned = g_spawn_async_with_pipes(directory, argv, child_env,
        G_SPAWN_DO_NOT_REAP_CHILD | G_SPAWN_SEARCH_PATH,
        NULL, NULL, &app->pid, &input_fd, &output_fd, &error_fd, &error);
    g_strfreev(child_env);
    g_free(directory);
    g_free(engine);

    if (!spawned) {
        report_error(app, "Не удалось запустить программу", error ? error->message : NULL);
        g_clear_error(&error);
        g_free(path);
        return;
    }
    if (requested_app)
        enter_app_window(app, path);
    g_free(path);

    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app->output_view));
    gtk_text_buffer_set_text(buffer, "", 0);
    app->input_fd = input_fd;
    app->child_exited = FALSE;
    app->stdout_open = TRUE;
    app->stderr_open = TRUE;
    app->finish_written = FALSE;
    set_status(app, "Выполняется");
    gtk_widget_set_sensitive(app->run_button, FALSE);
    gtk_widget_set_sensitive(app->stop_button, TRUE);
    gtk_widget_set_sensitive(app->browse_button, FALSE);
    gtk_widget_set_sensitive(app->input_entry, TRUE);
    gtk_widget_set_sensitive(app->send_button, TRUE);
    gtk_widget_grab_focus(app->input_entry);

    install_pipe_watch(app, output_fd, FALSE);
    install_pipe_watch(app, error_fd, TRUE);
    g_child_watch_add(app->pid, on_child_exit, app);
}

static void on_run_clicked(GtkButton *button, gpointer data)
{
    (void)button;
    run_program(data);
}

static void on_stop_clicked(GtkButton *button, gpointer data)
{
    (void)button;
    App *app = data;
    if (app->pid <= 0) {
        set_status(app, "Сейчас нет выполняющейся программы");
        return;
    }
    if (kill(app->pid, SIGTERM) == 0)
        set_status(app, "Остановка программы…");
    else
        report_error(app, "Не удалось остановить программу", g_strerror(errno));
}

static gboolean send_runtime_input(App *app, const gchar *input, gboolean echo)
{
    if (app->pid <= 0 || app->input_fd < 0) {
        report_error(app, "Сейчас программа не ожидает ввода", NULL);
        return FALSE;
    }
    gchar *line = g_strdup_printf("%s\n", input ? input : "");
    gsize length = strlen(line);
    gsize written = 0;
    while (written < length) {
        ssize_t result = write(app->input_fd, line + written, length - written);
        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0) {
            report_error(app, "Не удалось передать ввод программе", g_strerror(errno));
            break;
        }
        written += (gsize)result;
    }
    g_free(line);
    if (written != length)
        return FALSE;
    if (echo) {
        gchar *display = g_strdup_printf("> %s\n", input ? input : "");
        append_text(app, display);
        g_free(display);
    }
    return TRUE;
}

static void on_send_clicked(GtkButton *button, gpointer data)
{
    (void)button;
    App *app = data;
    const gchar *input = gtk_entry_get_text(GTK_ENTRY(app->input_entry));
    send_runtime_input(app, input, !app->app_mode);
    gtk_entry_set_text(GTK_ENTRY(app->input_entry), "");
    gtk_widget_grab_focus(app->input_entry);
}

static void on_app_button_clicked(GtkButton *button, gpointer data)
{
    App *app = g_object_get_data(G_OBJECT(button), "helix-app");
    gint event_id = GPOINTER_TO_INT(data);
    gchar *event_text = g_strdup_printf("%d", event_id);
    send_runtime_input(app, event_text, FALSE);
    g_free(event_text);
}

static void on_input_activate(GtkEntry *entry, gpointer data)
{
    (void)entry;
    on_send_clicked(NULL, data);
}

static void on_browse_clicked(GtkButton *button, gpointer data)
{
    (void)button;
    App *app = data;
    GtkWidget *dialog = gtk_file_chooser_dialog_new("Выберите программу Helix",
        GTK_WINDOW(app->window), GTK_FILE_CHOOSER_ACTION_OPEN,
        "Отмена", GTK_RESPONSE_CANCEL, "Открыть", GTK_RESPONSE_ACCEPT, NULL);
    GtkFileFilter *filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Файлы Helix (*.hlx)");
    gtk_file_filter_add_pattern(filter, "*.hlx");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);

    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            gtk_entry_set_text(GTK_ENTRY(app->path_entry), filename);
            set_status(app, "Файл выбран — нажми «Запуск»");
            g_free(filename);
        }
    }
    gtk_widget_destroy(dialog);
}

static void on_file_dropped(GtkWidget *widget, GdkDragContext *context, gint x, gint y,
                            GtkSelectionData *selection, guint info, guint time, gpointer data)
{
    (void)widget;
    (void)x;
    (void)y;
    (void)info;
    App *app = data;
    gboolean accepted = FALSE;
    gchar **uris = gtk_selection_data_get_uris(selection);
    if (uris && uris[0]) {
        GError *error = NULL;
        gchar *filename = g_filename_from_uri(uris[0], NULL, &error);
        if (filename) {
            gtk_entry_set_text(GTK_ENTRY(app->path_entry), filename);
            set_status(app, "Файл добавлен перетаскиванием — нажми «Запуск»");
            g_free(filename);
            accepted = TRUE;
        }
        g_clear_error(&error);
    }
    g_strfreev(uris);
    gtk_drag_finish(context, accepted, FALSE, time);
}

static void on_window_destroy(GtkWidget *widget, gpointer data)
{
    (void)widget;
    App *app = data;
    if (app->pid > 0)
        kill(app->pid, SIGTERM);
    gtk_main_quit();
}

static void add_css(void)
{
    static const gchar css[] =
        "window, .helix-root { background-color: #0c0c0c; color: #e6e6e6; }"
        "label { color: #e6e6e6; }"
        "textview, textview text { background-color: #0c0c0c; color: #e6e6e6; }"
        ".helix-output { font-family: monospace; font-size: 11pt; }"
        ".helix-app-output { font-family: Sans; font-size: 12pt; }"
        ".helix-status { color: #9cdcfe; padding: 4px 2px; }"
        "entry { background-color: #0c0c0c; color: #e6e6e6; caret-color: #ffffff;"
        " border: 1px solid #5a5a5a; border-radius: 1px; padding: 5px; }"
        "button { background-image: none; background-color: #242424; color: #f2f2f2;"
        " border: 1px solid #555555; border-radius: 2px; padding: 6px 12px; }"
        "button:hover { background-color: #353535; border-color: #777777; }"
        "button:disabled { color: #858585; background-color: #191919; }"
        "scrollbar trough { background-color: #151515; }"
        "scrollbar slider { background-color: #565656; border-radius: 3px; }";
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, css, -1, NULL);
    GdkScreen *screen = gdk_screen_get_default();
    if (screen)
        gtk_style_context_add_provider_for_screen(screen, GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

static GtkWidget *make_label(const gchar *text, gint width)
{
    GtkWidget *label = gtk_label_new(text);
    gtk_widget_set_size_request(label, width, -1);
    gtk_widget_set_halign(label, GTK_ALIGN_START);
    return label;
}

static gboolean run_initial_file(gpointer data)
{
    run_program(data);
    return G_SOURCE_REMOVE;
}

static void set_initial_file(App *app, const gchar *path)
{
    if (!path || !*path)
        return;
    gchar *absolute = g_canonicalize_filename(path, NULL);
    gtk_entry_set_text(GTK_ENTRY(app->path_entry), absolute);
    g_free(absolute);
    g_idle_add(run_initial_file, app);
}

int main(int argc, char **argv)
{
    signal(SIGPIPE, SIG_IGN);
    if (!gtk_init_check(&argc, &argv)) {
        g_printerr("Helix Terminal: нет доступного графического сеанса (X11/Wayland).\n");
        return 2;
    }

    App app = {0};
    app.input_fd = -1;
    add_css();

    app.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(app.window), "Helix 0.9.1 — Terminal");
    gtk_window_set_default_size(GTK_WINDOW(app.window), 1120, 760);
    gtk_window_set_position(GTK_WINDOW(app.window), GTK_WIN_POS_CENTER);

    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_style_context_add_class(gtk_widget_get_style_context(root), "helix-root");
    gtk_container_set_border_width(GTK_CONTAINER(root), 14);
    gtk_container_add(GTK_CONTAINER(app.window), root);

    app.toolbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_pack_start(GTK_BOX(root), app.toolbar, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(app.toolbar), make_label("ПРОГРАММА .HLX", 135), FALSE, FALSE, 0);
    app.path_entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(app.path_entry), "Выберите исходный файл .hlx");
    gtk_widget_set_hexpand(app.path_entry, TRUE);
    gtk_box_pack_start(GTK_BOX(app.toolbar), app.path_entry, TRUE, TRUE, 0);
    app.browse_button = gtk_button_new_with_label("Обзор...");
    gtk_box_pack_start(GTK_BOX(app.toolbar), app.browse_button, FALSE, FALSE, 0);
    app.run_button = gtk_button_new_with_label("▶  Запуск");
    gtk_widget_set_size_request(app.run_button, 110, -1);
    gtk_box_pack_start(GTK_BOX(app.toolbar), app.run_button, FALSE, FALSE, 0);
    app.stop_button = gtk_button_new_with_label("■  Стоп");
    gtk_widget_set_sensitive(app.stop_button, FALSE);
    gtk_box_pack_start(GTK_BOX(app.toolbar), app.stop_button, FALSE, FALSE, 0);
    app.clear_button = gtk_button_new_with_label("Очистить");
    gtk_box_pack_start(GTK_BOX(app.toolbar), app.clear_button, FALSE, FALSE, 0);

    app.app_surface = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    gtk_widget_set_hexpand(app.app_surface, TRUE);
    gtk_widget_set_vexpand(app.app_surface, TRUE);
    gtk_container_set_border_width(GTK_CONTAINER(app.app_surface), 24);
    gtk_box_pack_start(GTK_BOX(root), app.app_surface, TRUE, TRUE, 0);
    app.app_controls = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    app.app_button_box = app.app_controls;
    gtk_box_pack_start(GTK_BOX(app.app_surface), app.app_controls, FALSE, FALSE, 0);

    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    app.output_scrolled = scrolled;
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_hexpand(scrolled, TRUE);
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_box_pack_start(GTK_BOX(root), scrolled, TRUE, TRUE, 0);
    app.output_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(app.output_view), FALSE);
    gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(app.output_view), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(app.output_view), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(app.output_view), GTK_WRAP_CHAR);
    gtk_text_view_set_left_margin(GTK_TEXT_VIEW(app.output_view), 12);
    gtk_text_view_set_right_margin(GTK_TEXT_VIEW(app.output_view), 12);
    gtk_text_view_set_top_margin(GTK_TEXT_VIEW(app.output_view), 10);
    gtk_text_view_set_bottom_margin(GTK_TEXT_VIEW(app.output_view), 10);
    gtk_style_context_add_class(gtk_widget_get_style_context(app.output_view), "helix-output");
    gtk_container_add(GTK_CONTAINER(scrolled), app.output_view);
    GtkTextBuffer *output_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(app.output_view));
    gtk_text_buffer_create_tag(output_buffer, "stdout", "foreground", "#e5e5e5", NULL);
    gtk_text_buffer_create_tag(output_buffer, "stderr", "foreground", "#ff6b6b", NULL);

    GtkWidget *status_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_pack_start(GTK_BOX(root), status_row, FALSE, FALSE, 0);
    app.status_label = gtk_label_new("ГОТОВО · выберите файл .hlx");
    gtk_widget_set_halign(app.status_label, GTK_ALIGN_START);
    gtk_style_context_add_class(gtk_widget_get_style_context(app.status_label), "helix-status");
    gtk_box_pack_start(GTK_BOX(status_row), app.status_label, TRUE, TRUE, 0);

    app.input_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_pack_start(GTK_BOX(root), app.input_row, FALSE, FALSE, 0);
    app.input_label = make_label("ВВОД · ENTER", 130);
    gtk_box_pack_start(GTK_BOX(app.input_row), app.input_label, FALSE, FALSE, 0);
    app.input_entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(app.input_entry), "Программа запросит число через sense — нажмите Enter");
    gtk_widget_set_hexpand(app.input_entry, TRUE);
    gtk_widget_set_sensitive(app.input_entry, FALSE);
    gtk_box_pack_start(GTK_BOX(app.input_row), app.input_entry, TRUE, TRUE, 0);
    app.send_button = gtk_button_new_with_label("Отправить");
    gtk_widget_set_size_request(app.send_button, 125, -1);
    gtk_widget_set_sensitive(app.send_button, FALSE);
    gtk_box_pack_start(GTK_BOX(app.input_row), app.send_button, FALSE, FALSE, 0);

    g_signal_connect(app.run_button, "clicked", G_CALLBACK(on_run_clicked), &app);
    g_signal_connect(app.stop_button, "clicked", G_CALLBACK(on_stop_clicked), &app);
    g_signal_connect(app.browse_button, "clicked", G_CALLBACK(on_browse_clicked), &app);
    g_signal_connect(app.clear_button, "clicked", G_CALLBACK(on_clear_clicked), &app);
    g_signal_connect(app.send_button, "clicked", G_CALLBACK(on_send_clicked), &app);
    g_signal_connect(app.input_entry, "activate", G_CALLBACK(on_input_activate), &app);
    g_signal_connect(app.window, "destroy", G_CALLBACK(on_window_destroy), &app);

    append_text(&app, "Helix Runtime · x86-64\nВыберите `.hlx` или перетащите файл в окно, затем нажмите «Запуск».\nВвод программы отправляется по Enter.\n\n");
    gtk_widget_show_all(app.window);
    gtk_widget_hide(app.app_controls);
    gtk_widget_hide(app.app_surface);
    static const GtkTargetEntry drop_targets[] = {{"text/uri-list", 0, 0}};
    gtk_drag_dest_set(app.window, GTK_DEST_DEFAULT_ALL, (GtkTargetEntry *)drop_targets,
                      G_N_ELEMENTS(drop_targets), GDK_ACTION_COPY);
    g_signal_connect(app.window, "drag-data-received", G_CALLBACK(on_file_dropped), &app);
    if (argc > 1 && uses_helix_app(argv[1]))
        enter_app_window(&app, argv[1]);
    if (argc > 1)
        set_initial_file(&app, argv[1]);
    gtk_main();

    if (app.input_fd >= 0)
        close(app.input_fd);
    return 0;
}
