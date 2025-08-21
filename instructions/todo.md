## Context

You are assisting with a Rails gem called Historiographer. Your role is to make precise, surgical edits to the codebase based on specific tasks. The project has a complex architecture with interdependent components, so caution is required.

## Task:

We are going to PROPERLY implement Single Table Inheritance (STI) for Historiographer, in line with Rails best practices.

There is some existing code in here that implements STI, but it is not done correctly. We need to fix that.

## Requirements:

1. User can define a `type` for their class, and that will be used to identify the STI class
2. In keeping with STI conventions, the `type` should be a string, and the default value should be the class name
3. When a user creates a new instance of a class, the `type` should be set to the class name, and the class should automatically inherit the STI class

In historiographer, we use a `histories` table for each model, for example:

datasources => datasource_histories

With STI, it is okay for us to have:

class Datasource < ActiveRecord::Base
def refresh # implemented in sub-classes
end
end

class S3Datasource < Datasource
def refresh
s3.refresh
end
end

class DatasourceHistory < Datasource
end

class S3DatasourceHistory < DatasourceHistory
end

4. But the STI class should automatically inherit the STI class, allowing it to use methods defined on the STI class, meaning that S3DatasourceHistory should have access to the `refresh` method that uses s3

5. When we find an instance of DatasourceHistory, it should automatically give us the S3DatasourceHistory class if the `type` is "S3Datasource"

6. The History classes currently have a VERY tricky and complicated way of doing STI that allows them to both act as proper history classes, and "proxy all requests" to the original class. This causes complicated and subtle bugs, and we need to fix that. I would assume that we should do this by inheriting from the original class, which will handle regular inheritance... but then we maybe need to include Historiographer::History to gain access to the history functionality.

7. Implement tests which verify that the STI is working correctly, and that History objects can properly call all methods on the original class.

## Rules

### Do No Harm

- Do not remove any code that seems to be irrelevant to your task. You do not have full context of the application, so you should err on the side of NOT removing code, unless the code is clearly duplication.
- Preserve existing formatting, naming conventions, and code style whenever possible.
- Keep changes minimal and focused on the specific task at hand.

### Before Starting

- Look for any files you might need to understand the context better
- If you have any questions, DO NOT WRITE CODE. Ask the question. I will be happy to answer all your questions to your satisfaction before you start.
- Measure twice, cut once!
- Understand the full impact of your changes before implementing them.

### Working Process

1. **Analyze First**: Carefully review the code before suggesting any changes.
2. **Ask Questions**: If anything is unclear, ask before proceeding.
3. **Plan Your Approach**: Outline your intended changes before executing them.
4. **Make Minimal Changes**: Focus only on what's needed for the task.
5. **Explain Your Changes**: Document what you've done and why.

## Technology-Specific Guidelines

### Rails

- Be aware of model associations and their dependencies.
- Don't alter database migrations unless specifically asked.
- Pay attention to Rails conventions and patterns in the existing code.
- Be cautious when modifying controllers that might affect multiple views.

## Common Pitfalls to Avoid

- Adding unnecessary abstractions or "improvements" beyond the scope of the task
- Rewriting functional code in your preferred style when it's not needed
- Making major architectural changes when only small fixes are required
- Assuming you understand the full context of the application
- Using libraries or approaches not already in use in the project

## Communication Guidelines

- Be specific about what you're changing and why
- If you're uncertain about something, ask first
- Identify potential risks or side effects of your changes
- If you spot issues unrelated to your task, note them separately without fixing them
- Provide clear explanations of your thought process

Remember: Your primary goal is to complete the specific task assigned with minimal disruption to the existing codebase. Quality and precision are more important than clever or extensive changes.
