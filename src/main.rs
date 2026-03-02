use std::{
    fs::{ReadDir, read_dir},
    time::Duration,
};

use hyprland::{
    ctl::{Color, notify},
    hyprpaper::Error,
};

fn main() -> Result<(), Error> {
    let dir: ReadDir = read_dir("/sys/class/power_supply").expect("directory error");
    dir.for_each(|f| {
        let file = f.unwrap();
        if file.path().is_dir() {
            let files = read_dir(file.path()).unwrap();
            files.for_each(|f| {
                let file = f.unwrap();
                if file.path().is_file() {
                    if file.path().file_name().unwrap() == "capacity" {
                        let percentage: i32 = String::from_utf8(read(file.path()).unwrap())
                            .unwrap()
                            .parse()
                            .unwrap();
                        if percentage <= 15 {
                            battery_low(file.path().to_str().unwrap().to_string());
                        }
                    }
                }
            });
        }
    });
    Ok(())
}

fn battery_low(battery: String) {
    notify::call(
        notify::Icon::NoIcon,
        Duration::from_secs_f32(5.0),
        Color::new(255, 0, 0, 255),
        format!("battery is low! {}", battery),
    )
    .unwrap();
}
