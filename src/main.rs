use std::{
    fs::{read, read_dir},
    path::PathBuf,
    thread,
    time::Duration,
};

#[cfg(feature = "niri")]
use ::notify::notification::Notification;

#[cfg(feature = "hypr")]
use hyprland::{
    ctl::{Color, notify},
    hyprpaper::Error,
};

fn main() {
    let mut c_path: Option<PathBuf> = None;
    let mut charging = false;
    loop {
        thread::sleep(Duration::from_secs(1));

        if let Some(path) = &c_path {
            let s_file = path.parent().unwrap().join("status");
            let status = get_status(String::from_utf8(read(s_file).unwrap()).unwrap());
            dbg!(charging);
            if status != "Charging" {
                let percentage_raw = String::from_utf8(read(path).unwrap()).unwrap();
                let percentage = get_percentage(percentage_raw.clone());
                dbg!(percentage_raw);
                if percentage <= 20 && status != "Charging" {
                    battery_low(format!("Capacity {}", percentage));
                }

                if charging {
                    send_notification("battery discharging".to_string());
                    charging = false;
                }
            } else if !charging {
                send_notification("Battery charging".to_string());
                charging = true;
            }
            continue;
        }
        let dir = read_dir("/sys/class/power_supply").expect("directory error");
        dir.for_each(|f| {
            let file = f.expect("DirEntry error");
            dbg!(&file);
            if file.path().is_dir() {
                let files = read_dir(file.path()).unwrap();
                dbg!(&files);
                files.for_each(|f| {
                    let file = f.unwrap();
                    dbg!(&file);
                    if file.path().is_file() && file.path().file_name().unwrap() == "capacity" {
                        let percentage_raw = String::from_utf8(read(file.path()).unwrap()).unwrap();
                        let percentage = get_percentage(percentage_raw);
                        if percentage <= 20 {
                            battery_low(format!("Capacity {}", percentage));
                        }
                        c_path = Some(file.path());
                    }
                });
            }
        });
    }
}

fn get_percentage(path: String) -> i32 {
    match path.split_once('\n') {
        Some((key, _value)) => key.parse::<i32>().unwrap(),
        None => {
            dbg!("you haven't battery");
            0
        }
    }
}

fn get_status(path: String) -> String {
    match path.split_once('\n') {
        Some((key, _value)) => key.to_string(),
        None => {
            dbg!("you haven't battery");
            "".to_string()
        }
    }
}

#[cfg(feature = "niri")]
fn battery_low(battery: String) {
    send_notification(format!("Capacity very low! {}", battery));
}

#[cfg(feature = "hypr")]
fn battery_low(battery: String) {
    notify::call(
        notify::Icon::NoIcon,
        Duration::from_secs_f32(5.0),
        Color::new(255, 0, 0, 255),
        format!("battery is low! {}", battery),
    )
    .unwrap();
}

#[cfg(feature = "niri")]
fn send_notification(message: String) {
    Notification::init("battery-check");
    let not = Notification::notification_new("Battery", &message, "");
    not.notification_show();
}

mod tests {
    use crate::battery_low;

    #[test]
    fn battery_notification_start() {
        battery_low("30".to_string());
    }
}
