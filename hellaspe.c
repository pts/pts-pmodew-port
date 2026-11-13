#ifdef __DWLIBC__ 
#  include "dwlibc.h"
#else
#  include <string.h>
#  include <unistd.h>
#endif

long long llmul(long long a, long long b) {
  return (a + b) * (a - b);  /* Calls function __I8M. */
}

/* Poor man's printf(3). It's unbuffered. */
static void print(const char *msg) {
  (void)!write(1, msg, strlen(msg));
}

static char hello_msg[] = "He--o, World!\r\n";

int main(int argc, char **argv) {
  memset(hello_msg + 2, 'l', 2);
  print(hello_msg);
  for (; *argv; ++argv) {
    print(*argv);
    print("\r\n");
    if (strcmp(*argv, "green") == 0) {
      print("You've got the green flag!\r\n");
    }
  }
  return argc;
}
