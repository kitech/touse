
// interface need to implment
// error: undefined symbol 'tray_get_instance'
// error: undefined symbol 'tray_update'
// error: undefined symbol 'tray_exit'
// error: undefined symbol 'tray_init'
// error: undefined symbol 'tray_loop'

#include "tray.h"

#include <gtk/gtk.h>
#include <libappindicator/app-indicator.h>

#define TRAY_APPINDICATOR_ID "tray-id"

static AppIndicator *indicator = NULL;
static int loop_result = 0;

static struct tray *currentTrayStruct = NULL;


TRAY_EXPORT struct tray *tray_get_instance()
{
    return currentTrayStruct;
}

static void _tray_menu_cb(GtkMenuItem *item, gpointer data) {
  (void)item;
  struct tray_menu_item *m = (struct tray_menu_item *)data;
  m->cb(m);
}

static GtkMenuShell *_tray_menu(struct tray_menu_item *m) {
  GtkMenuShell *menu = (GtkMenuShell *)gtk_menu_new();
  for (; m != NULL && m->text != NULL; m++) {
    GtkWidget *item;
    // printf("create menu item %s %s ...\n", m->text, currentTrayStruct->icon_filepath);
    if (strcmp(m->text, "-") == 0) {
      item = gtk_separator_menu_item_new();
    } else {
      if (m->submenu != NULL) {
        item = gtk_menu_item_new_with_label(m->text);
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(item),
                                  GTK_WIDGET(_tray_menu(m->submenu)));
      } else {
        item = gtk_check_menu_item_new_with_label(m->text);
        gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item), !!m->checked);
      }
      gtk_widget_set_sensitive(item, !m->disabled);
      if (m->cb != NULL) {
        g_signal_connect(item, "activate", G_CALLBACK(_tray_menu_cb), m);
      }
    }
    gtk_widget_show(item);
    gtk_menu_shell_append(menu, item);
  }
  return menu;
}

 int tray_init(struct tray *tray) {
     currentTrayStruct = tray;
  if (gtk_init_check(0, NULL) == FALSE) {
    return -1;
  }
  // GtkIconTheme *icon_theme = gtk_icon_theme_get_default();
  // gtk_icon_theme_add_resource_path(icon_theme, "/home/gzleo/aprog/touse/pftray");
  // Then you can use "captain-cap" as the icon name
  
  indicator = app_indicator_new(TRAY_APPINDICATOR_ID, tray->icon_filepath,
                                APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  tray_update(tray);
  return 0;
}

 int tray_loop(int blocking) {
  gtk_main_iteration_do(blocking);
  return loop_result;
}
//
 void tray_update(struct tray *tray) {
  app_indicator_set_icon(indicator, tray->icon_filepath);
  // app_indicator_set_icon_full(indicator, tray->icon_filepath, "My App Indicator Icon");
  // GTK is all about reference counting, so previous menu should be destroyed
  // here
  app_indicator_set_menu(indicator, GTK_MENU(_tray_menu(tray->menu)));
}

 void tray_exit() { loop_result = -1; }
