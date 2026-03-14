name: Bug Report
description: Report a bug to help us improve Private Corporate AI.
labels: [bug]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: textarea
    id: description
    attributes:
      label: Bug Description
      description: A clear and concise description of what the bug is.
      placeholder: Describe the issue here...
    validations:
      required: true
  - type: textarea
    id: expected-behavior
    attributes:
      label: Expected Behavior
      description: A clear and concise description of what you expected to happen.
    validations:
      required: true
  - type: textarea
    id: actual-behavior
    attributes:
      label: Actual Behavior
      description: A clear and concise description of what actually happened.
    validations:
      required: true
  - type: textarea
    id: steps-to-reproduce
    attributes:
      label: Steps to Reproduce
      description: Provide a link to a live example, or an unambiguous set of steps to reproduce this bug.
      placeholder: |
        1. Go to '...'
        2. Click on '....'
        3. Scroll down to '....'
        4. See error
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: Please provide details about your environment.
      placeholder: |
        - OS: [e.g. Ubuntu 22.04, WSL2]
        - Mode: [e.g. FULL (GPU) or LITE (CPU)]
        - Docker Version: [e.g. 24.0.5]
        - LLM Model: [e.g. gemma2:9b]
    validations:
      required: true
  - type: textarea
    id: logs
    attributes:
      label: Relevant Logs
      description: Please include relevant logs from `make logs` or `make logs-rag`.
      render: shell
