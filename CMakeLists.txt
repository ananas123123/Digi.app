cmake_minimum_required(VERSION 3.21)
project(Digi LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(Digi
    src/main.cpp
    src/app/AppServices.cpp
    src/app/AppServices.h
    src/documents/DocumentService.cpp
    src/documents/DocumentService.h
)

qt_add_qml_module(Digi
    URI Digi
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/SideBar.qml
        qml/components/TopBar.qml
        qml/components/WorkspaceCard.qml
        qml/pages/HomePage.qml
        qml/pages/NotesPage.qml
        qml/themes/Theme.qml
)

target_link_libraries(Digi PRIVATE Qt6::Quick)

if(WIN32)
    set_target_properties(Digi PROPERTIES WIN32_EXECUTABLE TRUE)
endif()
