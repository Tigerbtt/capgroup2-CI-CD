terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


# Configure the AWS Provider
provider "aws" {
    region=var.region
}

# aws_ecr_repository.my_first_ecr_repo:
resource "aws_ecr_repository" "my_first_ecr_repo" {
    #arn                  = "arn:aws:ecr:us-west-2:962804699607:repository/capgroup2"
    #id                   = "capgroup2"
    #image_tag_mutability = "MUTABLE"
    name                 = join("",[var.config_user_alias, "ecr_repo"])
    #registry_id          = "962804699607"
    #repository_url       = "962804699607.dkr.ecr.us-west-2.amazonaws.com/capgroup2"
    #tags                 = {}
    #tags_all             = {}

    # encryption_configuration {
    #     encryption_type = "AES256"
    # }

    # image_scanning_configuration {
    #     scan_on_push = false
    # }
}

# aws_ecs_cluster.my_ecs_cluster:
resource "aws_ecs_cluster" "my_ecs_cluster" {
    # capacity_providers = [
    #     "FARGATE",
    #     "FARGATE_SPOT",
    # ]

    name = join("",[var.config_user_alias,"cluster"])

    configuration {
        execute_command_configuration {
            logging = "DEFAULT"
        }
    }

    setting {
        name  = "containerInsights"
        value = "disabled"
    }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = join("",[var.config_user_alias,"ecsTaskExecutionRole"])
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# aws_ecs_task_definition.my_ecs_task:
resource "aws_ecs_task_definition" "my_ecs_task" { #BNNT
    family = join("",[var.config_user_alias,"first-task"])
#    arn                      = "arn:aws:ecs:us-west-2:962804699607:task-definition/capgroup2-task:6"
#    arn_without_revision     = "arn:aws:ecs:us-west-2:962804699607:task-definition/capgroup2-task"
    container_definitions    = jsonencode(
        [
            {
#                cpu              = 0
#                environment      = []
#                environmentFiles = []
                image = aws_ecr_repository.my_first_ecr_repo.repository_url
                essential        = true # need in order for task to run
#                image            = "962804699607.dkr.ecr.us-west-2.amazonaws.com/capgroup2:latest"
                logConfiguration = {
                    logDriver     = "awslogs"
                    options       = {
                        awslogs-create-group  = "true"
                        awslogs-group         = "/ecs/capgroup2-task"
                        awslogs-region        = var.region
                        awslogs-stream-prefix = "ecs"
                    }
 #                   secretOptions = []
                }
 #               mountPoints      = []
                name             = "capgroup2-container"
                portMappings     = [
                    {
                        appProtocol   = "http"
                        containerPort = var.port
                        hostPort      = var.port
                        name          = join("",[var.config_user_alias,"port"])
                        protocol      = "tcp"
                    },
                ]
                # systemControls   = []
                # ulimits          = []
                # volumesFrom      = []
            },
        ]
    )
    cpu                      = "1024"
    execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
    # family                   = "capgroup2-task"
    # id                       = "capgroup2-task"
    memory                   = "3072"
    network_mode             = "awsvpc"
    requires_compatibilities = [
        "FARGATE",
    ]
#    revision                 = 6
    # tags                     = {}
    # tags_all                 = {}

    runtime_platform {
        cpu_architecture        = "X86_64"
        operating_system_family = "LINUX"
    }
}

# aws_ecs_service.my_ecs_service:
resource "aws_ecs_service" "my_ecs_service" {
    cluster                            = aws_ecs_cluster.my_ecs_cluster.id
    #deployment_maximum_percent         = 200
    #deployment_minimum_healthy_percent = 100
    desired_count                      = 1
    #enable_ecs_managed_tags            = true
    #enable_execute_command             = false
    #health_check_grace_period_seconds  = 0
    #iam_role                           = "/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
    #id                                 = "arn:aws:ecs:us-west-2:962804699607:service/capgroup2-cluster/capgroup2-service2"
    launch_type                        = "FARGATE"
    name                               = join("",[var.config_user_alias ,"service"])
    #platform_version                   = "1.4.0"
    #propagate_tags                     = "NONE"
    #scheduling_strategy                = "REPLICA"
    #tags                               = {}
    #tags_all                           = {}
    task_definition                    = aws_ecs_task_definition.my_ecs_task.arn
    #triggers                           = {}

    #alarms {
    #    alarm_names = []
    #    enable      = false
    #    rollback    = false
    #}

    #deployment_circuit_breaker {
    #    enable   = true
    #    rollback = true
    #}

    deployment_controller {
        type = "ECS"
    }

    network_configuration {
        assign_public_ip = true
        #security_groups  = [
        #    "sg-0fbd246e3f8b7ac55",
        #]
        #subnets          = [
        #    "subnet-007d29efbd34391e8",
        #    "subnet-0318ca5fab15964b0",
        #    "subnet-03b5d6e01b7642d0f",
        #    "subnet-06b7b0d283fab4d48",
        #    "subnet-06cf3161a5b4c77a0",
        #    "subnet-0bff8ba24e254058e",
        #    "subnet-0e802533c375c7061",
        #    "subnet-0ec28278a8fb8d138",
        #]
        subnets = [ # Referencing the default subnets
             "${aws_default_subnet.default_subnet_a.id}",
             "${aws_default_subnet.default_subnet_b.id}",
             "${aws_default_subnet.default_subnet_c.id}"
        ]
    }
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-west-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-west-2b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "us-west-2c"
}

# aws_codebuild_project.my_first_codebuild:
resource "aws_codebuild_project" "my_first_codebuild" {
    #arn                    = "arn:aws:codebuild:us-west-2:962804699607:project/capgroup2-awscodebuild"
    badge_enabled          = false
    build_timeout          = 60
    #concurrent_build_limit = 0
    #encryption_key         = "arn:aws:kms:us-west-2:962804699607:alias/aws/s3"
    #id                     = "arn:aws:codebuild:us-west-2:962804699607:project/capgroup2-awscodebuild"
    name                   = join("", [var.config_user_alias ,"awscodebuild"])
    project_visibility     = "PRIVATE"
    queued_timeout         = 480
    #service_role           = "arn:aws:iam::962804699607:role/capgroup2-codebuildrole"
    service_role           = "${aws_iam_role.my_iam_codebuild_role.arn}"
    #tags                   = {}
    #tags_all               = {}

    artifacts {
        encryption_disabled    = false
        override_artifact_name = false
        type                   = "NO_ARTIFACTS"
    }

    cache {
        modes = []
        type  = "NO_CACHE"
    }

    environment {
        compute_type                = "BUILD_GENERAL1_SMALL"
        image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
        image_pull_credentials_type = "CODEBUILD"
        privileged_mode             = true
        type                        = "LINUX_CONTAINER"
    }

    logs_config {
        cloudwatch_logs {
            status = "ENABLED"
        }

        #s3_logs {
        #    encryption_disabled = false
        #    status              = "DISABLED"
        #}
    }

    source {
        git_clone_depth     = 1
        insecure_ssl        = false
        location            = var.github
        report_build_status = false
        type                = "GITHUB"

        #git_submodules_config {
        #    fetch_submodules = false
        #}
    }
}

# aws_codepipeline.my_first_codepipeline:
resource "aws_codepipeline" "my_first_codepipeline" {
    name     = join("",[var.config_user_alias,"codepipeline"])
    #role_arn = "arn:aws:iam::962804699607:role/service-role/AWSCodePipelineServiceRole-us-west-2-capgroup2-codepipeline"
    role_arn = "${aws_iam_role.my_iam_pipeline_role.arn}"
    # tags     = {}
    # tags_all = {}

    artifact_store {
        location = "codepipeline-us-west-2-675714179853"
        type     = "S3"
    }
    
    stage {
        name = "Source"

        action {
            category         = "Source"
            configuration    = {
                "BranchName"           = "main"
                "ConnectionArn"        = "arn:aws:codestar-connections:us-west-2:962804699607:connection/d9a1a5bf-111b-46bd-9a59-82da2d37362b"
                "DetectChanges"        = "true"
                "FullRepositoryId"     = "Tigerbtt/capgroup2-CI-CD"
                "OutputArtifactFormat" = "CODE_ZIP"
            }
            input_artifacts  = []
            name             = "Source"
            namespace        = "SourceVariables"
            output_artifacts = [
                "SourceArtifact",
            ]
            owner            = "AWS"
            provider         = "CodeStarSourceConnection"
            # region           = var.region
            # run_order        = 1
            version          = "1"
        }
    }
    stage {
        name = "Build"

        action {
            category         = "Build"
            configuration    = {
                "ProjectName" = "${aws_codebuild_project.my_first_codebuild.name}"
            }
            
            input_artifacts  = [
                "SourceArtifact",
            ]
            name             = "Build"
            namespace        = "BuildVariables"
            output_artifacts = [
                "BuildArtifact",
            ]
            owner            = "AWS"
            provider         = "CodeBuild"
            # region           = var.region
            # run_order        = 1
            version          = "1"
        }
    }
    stage {
        name = "Deploy"

        action {
            category         = "Deploy"
            configuration    = {
                "ClusterName" = "${aws_ecs_cluster.my_ecs_cluster.name}"
                "FileName"    = "imagedefinitions.json"
                "ServiceName" = join("", ["${aws_ecs_cluster.my_ecs_cluster.name}", "/", "${aws_ecs_service.my_ecs_service.name}"])
            }
            input_artifacts  = [
                "BuildArtifact",
            ]
            name             = "Deploy"
            output_artifacts = []
            owner            = "AWS"
            provider         = "ECS"
            # region           = var.region
            # run_order        = 1
            version          = "1"
        }
    }
}

# aws_iam_role.my_iam_role:
resource "aws_iam_role" "my_iam_codebuild_role" {
    #arn                   = "arn:aws:iam::962804699607:role/capgroup2-codebuildrole"
    assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Effect    = "Allow"
                    Principal = {
                        Service = "codebuild.amazonaws.com"
                    }
                },
            ]
            #Version   = "2012-10-17"
        }
    )
    # create_date           = "2024-05-14T20:52:20Z"
    # description           = "Allows CodeBuild to call AWS services on your behalf."
    # force_detach_policies = false
    #id                    = join("",[var.config_user_alias,"codebuildrole"])
    managed_policy_arns   = [
        #"arn:aws:iam::962804699607:policy/service-role/CodeBuildBasePolicy-capgroup2-codebuildrole-us-west-2",
        "${aws_iam_policy.my_iam_codebuild_policy.arn}", 
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    ]
    #max_session_duration  = 3600
    name                  = join("",[var.config_user_alias,"codebuildrole"])
    #path                  = "/"
    # role_last_used        = [
    #     {
    #         last_used_date = "2024-05-15T18:47:04Z"
    #         region         = "us-west-2"
    #     },
    # ]
    # tags                  = {}
    # tags_all              = {}
    # unique_id             = "AROA6AK5B2HLYGTBYCMYO"
}

# aws_iam_role.my_iam_pipeline_role:
resource "aws_iam_role" "my_iam_pipeline_role" {
    #arn                   = "arn:aws:iam::962804699607:role/service-role/AWSCodePipelineServiceRole-us-west-2-capgroup2-codepipeline"
    assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Effect    = "Allow"
                    Principal = {
                        Service = "codepipeline.amazonaws.com"
                    }
                },
            ]
            #Version   = "2012-10-17"
        }
    )
    # create_date           = "2024-05-14T21:44:03Z"
    # force_detach_policies = false
    # id                    = "AWSCodePipelineServiceRole-us-west-2-capgroup2-codepipeline"
    managed_policy_arns   = [
        "arn:aws:iam::962804699607:policy/service-role/AWSCodePipelineServiceRole-us-west-2-capgroup2-codepipeline",
    ]
    #max_session_duration  = 3600
    #name                  = "AWSCodePipelineServiceRole-us-west-2-capgroup2-codepipeline"
    name                  = join("", ["AWSCodePipelineServiceRole-us-west-2-", var.config_user_alias, "codepipeline"])
    # path                  = "/service-role/"
    # role_last_used        = [
    #     {
    #         last_used_date = "2024-05-15T18:51:45Z"
    #         region         = "us-west-2"
    #     },
    # ]
    # tags                  = {}
    # tags_all              = {}
    # unique_id             = "AROA6AK5B2HL2OX5EV7D7"
}


# aws_iam_policy.my_iam_codebuild_policy:
resource "aws_iam_policy" "my_iam_codebuild_policy" {
    #arn       = "arn:aws:iam::962804699607:policy/service-role/CodeBuildBasePolicy-capgroup2-codebuildrole-us-west-2"
    #id        = "arn:aws:iam::962804699607:policy/service-role/CodeBuildBasePolicy-capgroup2-codebuildrole-us-west-2"
    name      = join("",["CodeBuildBasePolicy-", var.config_user_alias, "codebuildrole-us-west-2"])
    #path      = "/service-role/"
    policy    = jsonencode(
        {
            Statement = [
                {
                    Action   = [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                    ]
                    Effect   = "Allow"
                    Resource = [
                    "*",
                    #    "arn:aws:logs:us-west-2:962804699607:log-group:/aws/codebuild/capgroup2-awscodebuild",
                    #    "arn:aws:logs:us-west-2:962804699607:log-group:/aws/codebuild/capgroup2-awscodebuild:*",
                    ]
                },
                {
                    Action   = [
                        "s3:PutObject",
                        "s3:GetObject",
                        "s3:GetObjectVersion",
                        "s3:GetBucketAcl",
                        "s3:GetBucketLocation",
                    ]
                    Effect   = "Allow"
                    Resource = [
                    "*",
                    #    "arn:aws:s3:::codepipeline-us-west-2-*",
                    ]
                },
                {
                    Action   = [
                        "codebuild:CreateReportGroup",
                        "codebuild:CreateReport",
                        "codebuild:UpdateReport",
                        "codebuild:BatchPutTestCases",
                        "codebuild:BatchPutCodeCoverages",
                    ]
                    Effect   = "Allow"
                    Resource = [
                    "*",
                    #    "arn:aws:codebuild:us-west-2:962804699607:report-group/capgroup2-awscodebuild-*",
                    ]
                },
            ]
            Version   = "2012-10-17"
        }
    )
    #policy_id = "ANPA6AK5B2HLWVWY4BTWA"
    #tags      = {}
    #tags_all  = {}
}