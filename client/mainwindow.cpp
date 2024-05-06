#include "mainwindow.h"
#include "./ui_mainwindow.h"
#include <QGraphicsDropShadowEffect>
#include <QLineEdit>

void applyShadowEffectToLineEdit(QLineEdit *lineEdit) {
    if (!lineEdit) return; // Safety check

    QGraphicsDropShadowEffect *shadowEffect = new QGraphicsDropShadowEffect();
    shadowEffect->setBlurRadius(15);  // Adjust the blur radius
    shadowEffect->setOffset(0, 3);    // Set the offset of the shadow
    shadowEffect->setColor(QColor(0, 0, 0, 100)); // Set the color of the shadow

    lineEdit->setGraphicsEffect(shadowEffect);
}

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    applyShadowEffectToLineEdit(ui->lineEdit);
    applyShadowEffectToLineEdit(ui->lineEdit_2);
    applyShadowEffectToLineEdit(ui->lineEdit_3);
    applyShadowEffectToLineEdit(ui->lineEdit_4);
}

MainWindow::~MainWindow()
{
    delete ui;
}
