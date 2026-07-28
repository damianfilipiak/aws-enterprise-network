resource "aws_security_group" "internal_form_alb_sg" {
  name        = "Internal-Form-ALB-SG"
  description = "Internal form ALB access from VPN clients"
  vpc_id      = aws_vpc.enterprise_vpc.id

  ingress {
    description = "HTTP from Client VPN clients"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_client_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Internal-Form-ALB-SG" }
}

resource "aws_security_group" "internal_form_task_sg" {
  name        = "Internal-Form-Task-SG"
  description = "Task SG for internal form service"
  vpc_id      = aws_vpc.enterprise_vpc.id

  ingress {
    description     = "Allow ALB traffic to form app"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_form_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Internal-Form-Task-SG" }
}

resource "aws_security_group_rule" "efs_from_internal_form_tasks" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_form_task_sg.id
  security_group_id        = aws_security_group.efs_sg.id
  description              = "NFS from internal form ECS tasks"
}

resource "aws_lb" "internal_form_alb" {
  name               = "corp-internal-form-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_form_alb_sg.id]
  subnets            = [aws_subnet.private_user_subnet_a.id, aws_subnet.private_user_subnet_b.id]

  tags = { Name = "Internal-Form-ALB" }
}

resource "aws_lb_target_group" "internal_form_tg" {
  name        = "internal-form-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.enterprise_vpc.id

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "Internal-Form-TG" }
}

resource "aws_lb_listener" "internal_form_http" {
  load_balancer_arn = aws_lb.internal_form_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_form_tg.arn
  }
}

resource "aws_cloudwatch_log_group" "internal_form_logs" {
  name              = "/ecs/internal-ad-form"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "internal_form_task" {
  family                   = "internal-ad-form-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "internal-ad-form"
      image     = "public.ecr.aws/docker/library/python:3.11-slim"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      command = [
        "/bin/sh",
        "-c",
        <<-EOC
          cat > /tmp/server.py <<'PY'
          import json
          import os
          from datetime import datetime
          from http.server import BaseHTTPRequestHandler, HTTPServer
          from urllib.parse import parse_qs

          DATA_DIR = "/data/ad-form"
          DATA_FILE = os.path.join(DATA_DIR, "submissions.jsonl")
          os.makedirs(DATA_DIR, exist_ok=True)

          def read_rows():
              rows = []
              if os.path.exists(DATA_FILE):
                  with open(DATA_FILE, "r", encoding="utf-8") as f:
                      for line in f:
                          line = line.strip()
                          if line:
                              rows.append(json.loads(line))
              return rows

          class Handler(BaseHTTPRequestHandler):
              def _send(self, status, body, ctype="text/html; charset=utf-8"):
                  self.send_response(status)
                  self.send_header("Content-Type", ctype)
                  self.end_headers()
                  self.wfile.write(body.encode("utf-8"))

              def do_GET(self):
                  if self.path == "/healthz":
                      self._send(200, "ok", "text/plain; charset=utf-8")
                      return
                  rows = read_rows()[-25:]
                  table = "".join([
                      f"<tr><td>{r.get('ts','')}</td><td>{r.get('username','')}</td><td>{r.get('group','')}</td><td>{r.get('role','')}</td><td>{r.get('notes','')}</td></tr>"
                      for r in rows
                  ])
                  html = f"""
                  <html><head><title>Internal AD Form</title>
                  <style>
                  body{{font-family:Segoe UI,Arial,sans-serif;max-width:900px;margin:2rem auto;padding:0 1rem;}}
                  input,select,textarea,button{{width:100%;padding:.6rem;margin:.3rem 0;}}
                  table{{width:100%;border-collapse:collapse;margin-top:1rem;}}
                  td,th{{border:1px solid #ddd;padding:.5rem;text-align:left;}}
                  </style></head>
                  <body>
                    <h1>Internal AD Access Request</h1>
                    <form method='POST' action='/submit'>
                      <label>Username</label><input name='username' required />
                      <label>Group</label>
                      <select name='group'>
                        <option>GG_HR</option><option>GG_Finance</option><option>GG_Operations</option><option>GG_IT_Admins</option>
                      </select>
                      <label>Role</label><input name='role' required />
                      <label>Notes</label><textarea name='notes' rows='3'></textarea>
                      <button type='submit'>Submit</button>
                    </form>
                    <h2>Last submissions</h2>
                    <table><tr><th>Timestamp</th><th>User</th><th>Group</th><th>Role</th><th>Notes</th></tr>{table}</table>
                  </body></html>
                  """
                  self._send(200, html)

              def do_POST(self):
                  if self.path != "/submit":
                      self._send(404, "not found", "text/plain; charset=utf-8")
                      return
                  length = int(self.headers.get("Content-Length", "0"))
                  body = self.rfile.read(length).decode("utf-8")
                  data = parse_qs(body)
                  row = {
                      "ts": datetime.utcnow().isoformat() + "Z",
                      "username": data.get("username", [""])[0],
                      "group": data.get("group", [""])[0],
                      "role": data.get("role", [""])[0],
                      "notes": data.get("notes", [""])[0],
                  }
                  with open(DATA_FILE, "a", encoding="utf-8") as f:
                      f.write(json.dumps(row, ensure_ascii=True) + "\\n")
                  self.send_response(302)
                  self.send_header("Location", "/")
                  self.end_headers()

          HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
          PY
          python /tmp/server.py
        EOC
      ]
      mountPoints = [
        {
          sourceVolume  = "shared-data"
          containerPath = "/data"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/internal-ad-form"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "internal-form"
        }
      }
    }
  ])

  volume {
    name = "shared-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.enterprise_storage.id
      transit_encryption = "ENABLED"
    }
  }
}

resource "aws_ecs_service" "internal_form_service" {
  name            = "internal-ad-form-service"
  cluster         = aws_ecs_cluster.office_sim.id
  task_definition = aws_ecs_task_definition.internal_form_task.arn
  desired_count   = var.internal_form_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_user_subnet_a.id, aws_subnet.private_user_subnet_b.id]
    security_groups  = [aws_security_group.internal_form_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.internal_form_tg.arn
    container_name   = "internal-ad-form"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.internal_form_http,
    aws_iam_role_policy_attachment.ecs_task_execution_attach
  ]
}
