load("render.star", "render")
load("time.star", "time")

BLUE = "#1E3A5F"
GOLD = "#FFD700"
WHITE = "#FFFFFF"
GRAY = "#AAAAAA"

# Mindess School January 2026 Menu
# Source: https://www.ashland.k12.ma.us/departments/nutrition-services/school-menus
MENU = {
    # Week 1
    "2026-01-05": "Hot Dog",
    "2026-01-06": "Mozz Sticks",
    "2026-01-07": "Buffalo Chicken",
    "2026-01-08": "Pizza Party!",
    "2026-01-09": "Dutch Waffles",
    # Week 2
    "2026-01-12": "Rodeo Burger",
    "2026-01-13": "Mac N Cheese",
    "2026-01-14": "Chicken Drum",
    "2026-01-15": "Pizza Party!",
    "2026-01-16": "No School",
    # Week 3
    "2026-01-19": "No School",
    "2026-01-20": "Salsa Chicken",
    "2026-01-21": "Chop Suey",
    "2026-01-22": "Pizza Party!",
    "2026-01-23": "Cheese Omelet",
    # Week 4
    "2026-01-26": "Pulled Pork",
    "2026-01-27": "Cheese Ravioli",
    "2026-01-28": "Nachos",
    "2026-01-29": "Pizza Party!",
    "2026-01-30": "Coconut Fish",
}

def get_weekday_num(t):
    day_name = t.format("Monday")
    day_map = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}
    return day_map.get(day_name, 0)

def add_days(t, days):
    return t + time.parse_duration("%dh" % (days * 24))

def get_today_and_tomorrow(now):
    weekday = get_weekday_num(now)
    if weekday == 5:  # Saturday
        today = add_days(now, 2)  # Show Monday
        tomorrow = add_days(now, 3)  # Show Tuesday
    elif weekday == 6:  # Sunday
        today = add_days(now, 1)  # Show Monday
        tomorrow = add_days(now, 2)  # Show Tuesday
    elif weekday == 4:  # Friday
        today = now
        tomorrow = add_days(now, 3)  # Show Monday
    else:
        today = now
        tomorrow = add_days(now, 1)
    return today, tomorrow

def main(config):
    timezone = config.get("timezone") or "America/New_York"
    now = time.now().in_location(timezone)
    today, tomorrow = get_today_and_tomorrow(now)
    today_str = today.format("2006-01-02")
    tomorrow_str = tomorrow.format("2006-01-02")
    today_day = today.format("Mon")
    tomorrow_day = tomorrow.format("Mon")
    today_menu = MENU.get(today_str, "No menu")
    tomorrow_menu = MENU.get(tomorrow_str, "No menu")
    
    return render.Root(
        delay = 75,
        child = render.Box(
            color = BLUE,
            child = render.Column(
                expanded = True,
                main_align = "space_evenly",
                cross_align = "center",
                children = [
                    render.Text(content = today_day, font = "tom-thumb", color = GOLD),
                    render.Text(content = today_menu, font = "tom-thumb", color = WHITE),
                    render.Text(content = tomorrow_day, font = "tom-thumb", color = GOLD),
                    render.Text(content = tomorrow_menu, font = "tom-thumb", color = GRAY),
                ],
            ),
        ),
    )
