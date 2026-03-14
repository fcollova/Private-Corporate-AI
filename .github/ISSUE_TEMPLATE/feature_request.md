name: Feature Request
description: Suggest an idea for Private Corporate AI.
labels: [enhancement]
body:
  - type: textarea
    id: problem-to-solve
    attributes:
      label: Problem to Solve
      description: Is your feature request related to a problem? Please describe.
      placeholder: I'm always frustrated when [...]
    validations:
      required: true
  - type: textarea
    id: proposed-solution
    attributes:
      label: Proposed Solution
      description: A clear and concise description of what you want to happen.
    validations:
      required: true
  - type: textarea
    id: alternatives-considered
    attributes:
      label: Alternatives Considered
      description: A clear and concise description of any alternative solutions or features you've considered.
  - type: textarea
    id: additional-context
    attributes:
      label: Additional Context
      description: Add any other context or screenshots about the feature request here.
