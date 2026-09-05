#include <windows.h>
#include <stdio.h>
#include <time.h>

int main() {
    // Get the current time
    time_t now;
    struct tm *timeinfo;

    time(&now);
    timeinfo = localtime(&now);

    // Format the current time
    char datetime[40];
    strftime(datetime, sizeof(datetime), "%Y-%m-%dT%H-%M-%S", timeinfo);

    // Store the current datetime in an environment variable
    char *env_var = "_currentdatetime";
    SetEnvironmentVariable(env_var, datetime);

    // Print the current datetime
    // printf("Current datetime: %s\n", datetime);
    printf("%s\n", datetime);

    return 0;
}
