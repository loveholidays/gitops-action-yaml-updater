local backstage = import 'backstage.libsonnet';
local Define = backstage.Define;
local Component = backstage.Component;
local Link = backstage.Link;
local Api = backstage.Api;

Define([
  Component(
    name='GitOps Action YAML Updater',
    description='GitHub Action used for updating image tags in GitOps managed repositories.',
    type='library',
    lifecycle='production',
    repository='loveholidays/gitops-action-yaml-updater',
    owner='platform-infrastructure',
    system='cicd',
    tags=['github', 'gha', 'gitops'],
    dependsOn=[
      'resource:github',
    ],
  )
])
