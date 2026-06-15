import sys
import os
from urllib.parse import unquote
from urllib.request import url2pathname
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Slot, QUrl
from PySide6.QtQuickControls2 import QQuickStyle

def get_base_path():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

def get_resource_path():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

class DocumentBackend(QObject):
    def __init__(self, engine):
        super().__init__()
        self.engine = engine
        self.current_filepath = None
        self.last_saved_text = ""
        self.base_path = get_base_path()
        self.resource_path = get_resource_path()
        self.settings_path = os.path.join(self.base_path, "settings.json")
        self.theme_path = os.path.join(self.resource_path, "theme.json")
        self.theme = self.load_theme()
        self.working_dir = self.load_working_dir()

    def _url_to_path(self, file_url):
        if file_url.startswith("file:///"):
            return os.path.normpath(url2pathname(file_url[8:]))
        return file_url

    def load_theme(self):
        import json
        default_theme = {
            "window": {"background": "#FFFFFF", "title": "abcdef editor"},
            "editor": {"fontFamily": "iAWriterDuoV.ttf", "fontSize": 18, "fontWeight": 475,
                       "textColor": "#000000", "selectionColor": "#C2E8FF", "selectedTextColor": "#1A1A1A",
                       "caretColor": "#007AFF", "caretWidth": 4, "caretRadius": 2, "placeholderColor": "#999999"},
            "dialog": {"background": "#FFFFFF", "borderColor": "#E0E0E0", "borderWidth": 1,
                       "borderRadius": 10, "textColor": "#000000", "padding": 24,
                       "footerBackground": "#F8F8F8", "buttonBackground": "#F1F5F9",
                       "buttonHoverBackground": "#E2E8F0", "buttonTextColor": "#334155",
                       "buttonBorderColor": "#D1D5DB"},
            "helpDialog": {"titleColor": "#0F172A", "titleFontSize": 16, "titleFontWeight": 600,
                           "dividerColor": "#E2E8F0", "keyBadgeBackground": "#F1F5F9",
                           "keyBadgeBorderColor": "#E2E8F0", "keyBadgeBorderWidth": 1,
                           "keyBadgeBorderRadius": 5, "keyBadgeHeight": 24, "keyFontFamily": "Consolas",
                           "keyFontSize": 12, "keyTextColor": "#334155", "descriptionColor": "#475569",
                           "descriptionFontSize": 13},
            "commandPalette": {"background": "#FFFFFF", "borderColor": "#E2E8F0", "borderWidth": 1,
                               "borderRadius": 8, "shadowColor": "#000000", "promptColor": "#64748B",
                               "inputTextColor": "#0F172A", "placeholderColor": "#94A3B8",
                               "hoverColor": "#F1F5F9", "fileNameColor": "#0F172A", "fileNameFontSize": 14,
                               "filePathColor": "#64748B", "filePathFontSize": 11, "noResultsColor": "#94A3B8"},
            "dropOverlay": {"backgroundColor": "#F0F9FF", "backgroundOpacity": 0.95,
                            "borderColor": "#007AFF", "borderWidth": 3, "titleColor": "#0F172A",
                            "titleFontSize": 18, "subtitleColor": "#64748B", "subtitleFontSize": 14,
                            "iconFontSize": 48}
        }
        if os.path.exists(self.theme_path):
            try:
                with open(self.theme_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                for section, values in default_theme.items():
                    if section not in data:
                        data[section] = values
                    else:
                        for key, val in values.items():
                            if key not in data[section]:
                                data[section][key] = val
                return data
            except Exception as e:
                print(f"Error reading theme: {e}")
        return default_theme

    @Slot(result=dict)
    def get_theme(self):
        return self.theme

    def load_working_dir(self):
        from PySide6.QtCore import QStandardPaths
        default_dir = QStandardPaths.writableLocation(QStandardPaths.DocumentsLocation)
        self.full_screen_width = 700
        if os.path.exists(self.settings_path):
            try:
                import json
                with open(self.settings_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    saved_dir = data.get("working_dir")
                    self.full_screen_width = data.get("full_screen_width", 700)
                    theme_file = data.get("theme", "theme.json")
                    self.theme_path = os.path.join(self.resource_path, theme_file)
                    self.theme = self.load_theme()
                    if saved_dir and os.path.exists(saved_dir):
                        return os.path.normpath(saved_dir)
            except Exception as e:
                print(f"Error reading settings: {e}")
        return os.path.normpath(default_dir)

    def save_working_dir(self, directory):
        if not directory or not os.path.exists(directory):
            return
        self.working_dir = os.path.normpath(directory)
        try:
            import json
            data = {}
            if os.path.exists(self.settings_path):
                try:
                    with open(self.settings_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                except Exception:
                    pass
            data["working_dir"] = self.working_dir
            data["full_screen_width"] = self.full_screen_width
            data["theme"] = data.get("theme", "theme.json")
            with open(self.settings_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
        except Exception as e:
            print(f"Error saving settings: {e}")

    @Slot(result=int)
    def get_full_screen_width(self):
        return self.full_screen_width

    @Slot(int)
    def save_full_screen_width(self, width):
        self.full_screen_width = width
        try:
            import json
            data = {}
            if os.path.exists(self.settings_path):
                try:
                    with open(self.settings_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                except Exception:
                    pass
            data["full_screen_width"] = self.full_screen_width
            data["working_dir"] = self.working_dir
            data["theme"] = data.get("theme", "theme.json")
            with open(self.settings_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
        except Exception as e:
            print(f"Error saving settings: {e}")

    @Slot(result=bool)
    def has_filepath(self):
        return self.current_filepath is not None

    @Slot()
    def clear_current_filepath(self):
        self.current_filepath = None
        self.last_saved_text = ""

    @Slot(str, result=bool)
    def is_modified(self, current_text):
        return current_text != self.last_saved_text

    @Slot(result=str)
    def get_working_dir(self):
        return self.working_dir

    @Slot(result=str)
    def get_working_dir_url(self):
        return QUrl.fromLocalFile(self.working_dir).toString()

    @Slot(result=list)
    def get_files_list(self):
        files_list = []
        if not self.working_dir or not os.path.exists(self.working_dir):
            return files_list

        ignored_dirs = {'.git', '.svn', '.hg', 'node_modules', '__pycache__', 'venv', '.venv', 'build', 'dist', '.gemini', 'brain'}
        allowed_extensions = {'.txt', '.md'}

        for root, dirs, files in os.walk(self.working_dir):
            dirs[:] = [d for d in dirs if d not in ignored_dirs and not d.startswith('.')]
            for file in files:
                if file.startswith('.'):
                    continue
                ext = os.path.splitext(file)[1].lower()
                if ext not in allowed_extensions:
                    continue
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, self.working_dir)
                files_list.append({
                    "name": file,
                    "rel_path": rel_path.replace('\\', '/'),
                    "abs_path": abs_path.replace('\\', '/')
                })
                if len(files_list) >= 2000:
                    break
            if len(files_list) >= 2000:
                break
        return files_list

    @Slot(str)
    def handle_open_file(self, file_url):
        filepath = self._url_to_path(file_url)
        if not os.path.exists(filepath):
            return

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                text = f.read()
            self.current_filepath = filepath
            self.last_saved_text = text
            self.save_working_dir(os.path.dirname(filepath))
            root = self.engine.rootObjects()[0]
            root.loadDocumentText(text)

        except Exception as e:
            print(f"Error reading file: {e}")

    @Slot(str, str)
    def handle_save_file(self, file_url, text):
        if not file_url and self.current_filepath:
            filepath = self.current_filepath
        elif file_url:
            filepath = self._url_to_path(file_url)
        else:
            root = self.engine.rootObjects()[0]
            root.openSaveDialog()
            return

        try:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(text)
            self.current_filepath = filepath
            self.last_saved_text = text
            self.save_working_dir(os.path.dirname(filepath))
            print(f"Saved to: {filepath}")

        except Exception as e:
            print(f"Error saving file: {e}")

    @Slot(str)
    def handle_check_quit(self, current_text):
        if current_text != self.last_saved_text:
            root = self.engine.rootObjects()[0]
            root.showCloseDialog()
        else:
            root = self.engine.rootObjects()[0]
            root.confirmQuit()


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(os.path.join(get_resource_path(), "logo.ico")))
    QQuickStyle.setStyle("Basic")
    engine = QQmlApplicationEngine()

    backend = DocumentBackend(engine)
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = os.path.join(get_resource_path(), "main.qml")
    engine.load(QUrl.fromLocalFile(qml_file))

    if not engine.rootObjects():
        sys.exit(-1)

    root_object = engine.rootObjects()[0]
    root_object.openFileRequested.connect(backend.handle_open_file)
    root_object.saveFileRequested.connect(backend.handle_save_file)
    root_object.checkBeforeQuit.connect(backend.handle_check_quit)

    sys.exit(app.exec())
