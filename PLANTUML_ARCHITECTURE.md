# PlantUML Діаграми для My D App

## 1. Архітектура системи (Component + Communication)

```plantuml
@startuml My_D_App_Architecture

!theme plain

package "Frontend Layer" {
  actor User
  component "Browser" as browser {
    component "ERB Views (53 files)" as views
    component "Turbo Rails" as turbo
    component "Stimulus Controllers" as stimulus
    component "Tailwind CSS" as tailwind
  }
}

package "Backend Layer" {
  component "Rails 8.1" as rails {
    component "Routes (RESTful)" as routes
    component "11 Controllers" as controllers
    component "Devise Auth" as devise
    component "4 Services" as services {
      component "BatchShowtimeCreator" as batch
      component "RegressionTrainer" as trainer
      component "ReportPdfGenerator" as pdf_report
      component "TicketPdfGenerator" as pdf_ticket
    }
  }
}

package "Data Layer" {
  database "SQLite3" as db {
    component "14 Models" as models {
      note right of models
        • Company, Cinema
        • User (with roles)
        • Movie, Hall, Seat
        • Showtime, Ticket
        • Product, Workday
        • Report, Forecast
        • ForecastRun
      end note
    }
  }
  component "Active Storage" as storage
}

package "Async Processing" {
  component "Solid Queue" as queue {
    component "Job Scheduler" as scheduler
    component "ForecastRunnerJob" as f_runner
    component "ForecastAccuracyJob" as f_accuracy
    component "Recurring Tasks" as recurring
  }
}

package "Infrastructure" {
  component "Solid Cache" as cache
  component "Solid Cable (WebSocket)" as cable
  component "Puma Web Server" as puma
}

' Relationships
User -->|Clicks| browser
browser -->|Render| views
views -->|Fetch API\n(async/await)| routes
routes -->|JSON/HTML| browser
browser -->|Turbo| turbo
turbo -->|Update DOM| views

routes -->|CRUD Ops| models
routes -->|Auth Check| devise
routes -->|Business Logic| services
services -->|Read/Write| models

models -->|Persist| db
db -->|Queries| controllers

routes -->|Enqueue| queue
queue -->|Schedule| scheduler
f_runner -->|Process| models
f_accuracy -->|Analyze| models
recurring -->|Trigger| queue

services -->|Store| storage
routes -->|Cache| cache

puma -->|Serve| rails

@enduml
```

---

## 2. Entity Relationship Diagram (ERD - Дані та їх зв'язки)

```plantuml
@startuml My_D_App_ERD

!theme plain

entity "Company" {
  *id : integer
  --
  name : string
  domain_prefix : string
  created_at : datetime
}

entity "Cinema" {
  *id : integer
  --
  name : string
  address : string
  company_id : FK
  created_at : datetime
}

entity "User" {
  *id : integer
  --
  email : string
  encrypted_password : string
  role : enum (admin/manager/staff)
  company_id : FK
  cinema_id : FK
  created_at : datetime
}

entity "Movie" {
  *id : integer
  --
  title : string
  genre : string
  duration_minutes : integer
  release_date : date
  company_id : FK
  created_at : datetime
}

entity "Hall" {
  *id : integer
  --
  name : string
  capacity : integer
  rows : integer
  cols : integer
  cinema_id : FK
  created_at : datetime
}

entity "Seat" {
  *id : integer
  --
  row : integer
  col : integer
  hall_id : FK
  created_at : datetime
}

entity "Showtime" {
  *id : integer
  --
  start_time : datetime
  end_time : datetime
  price : decimal
  movie_id : FK
  hall_id : FK
  created_at : datetime
}

entity "Ticket" {
  *id : integer
  --
  status : enum (sold/pending/cancelled)
  price : decimal
  showtime_id : FK
  seat_id : FK
  workday_id : FK
  created_at : datetime
}

entity "Product" {
  *id : integer
  --
  name : string
  price : decimal
  category : string
  cinema_id : FK
  created_at : datetime
}

entity "Workday" {
  *id : integer
  --
  date : date
  status : enum (active/closed)
  cinema_id : FK
  created_at : datetime
}

entity "Report" {
  *id : integer
  --
  total_revenue : decimal
  ticket_revenue : decimal
  bar_sales_total : decimal
  product_snapshots : jsonb
  workday_id : FK
  created_at : datetime
}

entity "Forecast" {
  *id : integer
  --
  predicted_tickets : decimal
  predicted_fill_pct : decimal
  showtime_at : datetime
  forecast_run_id : FK
  hall_id : FK
  showtime_id : FK
  movie_id : FK
  created_at : datetime
}

entity "ForecastRun" {
  *id : integer
  --
  horizon_days : integer
  model : string
  model_weights : jsonb
  run_at : datetime
  created_at : datetime
}

' Relationships
Company ||--o{ Cinema : "has"
Company ||--o{ User : "has"
Company ||--o{ Movie : "has"
Cinema ||--o{ Hall : "has"
Cinema ||--o{ Product : "has"
Cinema ||--o{ Workday : "has"
Cinema ||--o{ User : "has"
Hall ||--o{ Seat : "has"
Hall ||--o{ Showtime : "has"
Hall ||--o{ Forecast : "relates to"
Movie ||--o{ Showtime : "has"
Showtime ||--o{ Ticket : "has"
Showtime ||--o{ Forecast : "predicts"
Seat ||--o{ Ticket : "has"
Workday ||--o{ Ticket : "groups"
Workday ||--o{ Report : "generates"
ForecastRun ||--o{ Forecast : "contains"

@enduml
```

---

## 3. Послідовність операцій - Продаж квитка

```plantuml
@startuml Ticket_Sale_Flow

!theme plain

participant User
participant Browser
participant "Turbo\n(JS)" as turbo
participant "Rails\nController" as controller
participant "Ticket\nService" as service
participant "Database" as db
participant "PDF\nGenerator" as pdf
participant "Queue\n(Jobs)" as queue

User->Browser: Вибирає квиток
Browser->Browser: Stimulus event handler
Browser->turbo: Fetch POST /tickets
turbo->controller: HTTP POST
controller->service: Create ticket\n(validation + price)
service->db: Save ticket
db-->service: Ticket created
service->db: Generate PDF\n(async)
db-->service: Ticket object
service-->controller: JSON response
controller-->turbo: {"status": "success"}
turbo->Browser: Update DOM\n(remove seat)
Browser-->User: Show confirmation

opt Payment modal
  User->Browser: Confirm payment
  Browser->controller: POST confirm
  controller->queue: Enqueue\nTicketPdfGeneratorJob
  queue-->db: Process async
  db-->pdf: Generate batch PDF
  pdf-->User: Download link
end

@enduml
```

---

## 4. Послідовність операцій - Генерація прогнозів

```plantuml
@startuml Forecast_Generation_Flow

!theme plain

participant "Scheduler\n(Recurring)" as cron
participant "Solid Queue" as queue
participant "ForecastRunnerJob" as job
participant "Database" as db
participant "ML Model\n(Regression)" as model
participant "Accuracy Job" as accuracy
participant "Logs" as logs

cron->queue: Trigger ForecastRunnerJob\n(7 days horizon)
queue->job: Start execution
job->db: Gather training data\n(past 60 days showtimes)
db-->job: Showtimes + ticket counts
job->db: Filter by segment\n(weekday_day, weekday_night, weekend)
db-->job: Segmented data
job->model: Train Ridge models\n(per hall, per segment)
model-->job: Model weights
job->db: Create ForecastRun\nrecord with weights
job->db: Generate Forecast\nrecords (7 days out)
db-->job: Done

job->logs: Log MAPE metrics\nby segment

par Accuracy Check
  queue->accuracy: Trigger\nForecastAccuracyJob
  accuracy->db: Compare 7 days ago\npredictions vs actual
  accuracy->db: Calculate MAPE per hall
  accuracy-->logs: Log accuracy report
end

queue-->db: Mark jobs as completed

@enduml
```

---

## 5. Потік аутентифікації та авторизації

```plantuml
@startuml Auth_Flow

!theme plain

actor User
participant "Browser" as browser
participant "Devise" as devise
participant "Controller" as controller
participant "User Model" as user_model
participant "Database" as db

User->browser: Clicks "Увійти"
browser->devise: GET /users/sign_in
devise-->browser: Render login form\n(Devise customized)

User->browser: Enter email + password
browser->browser: Stimulus validation
browser->devise: POST /users/sign_in
devise->user_model: authenticate(email, password)
user_model->db: Find user by email
db-->user_model: User record
user_model->user_model: bcrypt comparison
user_model-->devise: ✓ Match

devise->devise: Create session
devise-->browser: Redirect + set cookie
browser->browser: Store session

browser->controller: GET /any_page
controller->devise: Check current_user
devise->devise: Read session cookie
devise-->controller: User object

alt Admin/Manager
  controller->controller: Check role
  controller-->browser: Show admin panel
else Staff
  controller->controller: Check cinema_id
  controller-->browser: Show staff view
end

@enduml
```

---

## Як використовувати ці діаграми

### Варіант 1: Online Editor
1. Перейти на https://www.plantuml.com/plantuml/uml/
2. Скопіювати весь вміст однієї з діаграм (від @startuml до @enduml)
3. Вставити в редактор
4. Натиснути "Render"

### Варіант 2: VS Code
1. Встановити розширення "PlantUML"
2. Створити файл `diagram.puml` 
3. Вставити вміст
4. Right-click → "PlantUML: Preview"

### Варіант 3: Локально (CLI)
```bash
brew install plantuml  # або apt-get на Linux
plantuml diagram.puml
# Створить diagram.png
```

---

## Рекомендація

**Найкраще почати з діаграми #1 (Architecture)** - вона дає найбільш повну картину системи.

Потім **#2 (ERD)** - щоб розуміти структуру даних.

А **#3, #4, #5** - для вивчення конкретних бізнес-потоків.
