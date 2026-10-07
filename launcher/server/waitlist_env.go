package main

import (
	"bufio"
	"errors"
	"os"
	"strings"
)

type WaitlistEnvironment struct{ DatabaseURL, Origin string }

func LoadWaitlistEnvironment(path string) (WaitlistEnvironment, error) {
	values := map[string]string{}
	allowed := map[string]bool{"PERDIDOS_WAITLIST_DATABASE_URL": true, "PERDIDOS_SITE_ORIGIN": true}
	file, err := os.Open(path)
	if err == nil {
		defer file.Close()
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			key, value, found := strings.Cut(line, "=")
			if found && allowed[key] {
				values[key] = strings.TrimSpace(value)
			}
		}
		if err = scanner.Err(); err != nil {
			return WaitlistEnvironment{}, errors.New("could not read private waitlist configuration")
		}
	} else if !os.IsNotExist(err) {
		return WaitlistEnvironment{}, errors.New("could not read private waitlist configuration")
	}
	for key := range allowed {
		if value := os.Getenv(key); value != "" {
			values[key] = value
		}
	}
	if values["PERDIDOS_SITE_ORIGIN"] == "" {
		values["PERDIDOS_SITE_ORIGIN"] = "https://devalexandre.github.io"
	}
	return WaitlistEnvironment{values["PERDIDOS_WAITLIST_DATABASE_URL"], values["PERDIDOS_SITE_ORIGIN"]}, nil
}
