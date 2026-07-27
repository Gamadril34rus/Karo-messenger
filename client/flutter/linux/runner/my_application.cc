#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

G_DECLARE_FINAL_TYPE(MyApplication, my_application, MY, APPLICATION,
                     GtkApplication)

struct _MyApplication {
  GtkApplication parent_instance;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void my_application_activate(GApplication *app) {
  GtkWindow *window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(app)));
  gtk_window_set_title(window, "ЧАРО");
  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlFlutterView) flutter_view = fl_flutter_view_new();

  gtk_widget_show(GTK_WIDGET(flutter_view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(flutter_view));

  gtk_widget_show(GTK_WIDGET(window));
}

static void my_application_class_init(MyApplicationClass *klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
}

static void my_application_init(MyApplication *self) {}

MyApplication *my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", "com.charo.messenger",
                                     nullptr));
}
