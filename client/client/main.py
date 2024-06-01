# This Python file uses the following encoding: utf-8
import sys
import requests

from PySide6.QtWidgets import QApplication, QMainWindow, QWidget

# Important:
# You need to run the following command to generate the ui_form.py file
#     pyside6-uic form.ui -o ui_form.py, or
#     pyside2-uic form.ui -o ui_form.py
from ui_form import Ui_MainWindow
from ui_login import Ui_Form
from ui_dashboard import Ui_Dashboard


API_URL = 'https://api.hung3a8.dev'

class MainWindow(QMainWindow):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.ui = Ui_MainWindow()
        self.ui.setupUi(self)
        self.login_widget = QWidget()
        self.dashboard_widget = QWidget()

        self.login = Ui_Form()
        self.login.setupUi(self.login_widget)
        self.login.pushButton.clicked.connect(self.handle_login)
        self.dashboard = Ui_Dashboard()
        self.dashboard.setupUi(self.dashboard_widget)

        self.error = self.login.label

        self.setCentralWidget(self.login_widget)

    def handle_login(self):
        user = self.login.lineEdit.text()
        password = self.login.lineEdit_2.text()
        self.error.setText('')
        res = requests.post(f"{API_URL}/auth/auth/login", json={
            'username': user,
            'password': password
        })

        if res.status_code == 201:
            self.setCentralWidget(self.dashboard_widget)
        else:
            self.error.setText('Invalid username or password')


if __name__ == "__main__":
    app = QApplication(sys.argv)
    widget = MainWindow()
    widget.show()
    sys.exit(app.exec())
