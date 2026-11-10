#include <dwlibc.h>

/* Poor man's printf(3). It's unbuffered. */
static void print(const char *msg) {
  (void)!write(1, msg, strlen(msg));
}

static char hello_msg[] = "He--o, World!\r\n";

int main1(const char *cmdline) {
  memset(hello_msg + 2, 'l', 2);
  print(hello_msg);
  print(cmdline);
  print("\r\n");
  if (strcmp(cmdline, "green") == 0) {
    print("You've got the green flag!\r\n");
  }
  return 0;
}
