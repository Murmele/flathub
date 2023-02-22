flatpak remote-delete WeatherAppRepo
flatpak remote-add WeatherAppRepo WeatherAppRepo --no-gpg-verify --if-not-exists
flatpak install WeatherAppRepo com.gitlab.Murmele.WeatherApp
