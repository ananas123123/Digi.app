cmake_minimum_required(VERSION 3.21)
project(Argon LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Pdf PdfQuick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(Argon
    src/main.cpp
    src/app/AppPaths.cpp
    src/app/AppPaths.h
    src/app/AppServices.cpp
    src/app/AppServices.h
    src/analytics/DailyAnalyticsService.cpp
    src/analytics/DailyAnalyticsService.h
    src/documents/DocumentService.cpp
    src/documents/DocumentService.h
    src/search/SearchService.cpp
    src/search/SearchService.h
    src/search/DropImportWorker.cpp
    src/search/DropImportWorker.h
)

qt_add_qml_module(Argon
    URI Argon
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/SideBar.qml
        qml/components/TimerController.qml
        qml/components/TopBar.qml
        qml/components/WorkspaceCard.qml
        qml/pages/NotesPage.qml
        qml/pages/TimerPage.qml
        qml/pages/ResourcesPage.qml
        qml/pages/AnalyticsPage.qml
        qml/pages/DocPage.qml
        qml/themes/Theme.qml
    RESOURCES
        qml/assets/icons/Settings/setting-icon.png
)

target_link_libraries(Argon PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Pdf Qt6::PdfQuick)

if(WIN32)
    set_target_properties(Argon PROPERTIES WIN32_EXECUTABLE TRUE)
endif()
