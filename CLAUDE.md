# UDSim: User Design Simulator

## Overview

UDSim is a microprocessor design time simulation infrastructure that models software development projects using Monte Carlo simulation. It predicts project timelines, effort requirements, and resource allocation for complex engineering projects.

The simulator includes data gathered from several real projects and uses two different architectures:
- **Legacy Architecture** (`lib/UDSim.rb`) - Original implementation with XML-based configuration
- **New Architecture** (`udsim2.rb` + `src/`) - Modernized implementation with improved modularity

## Quick Start

### Using the New Architecture (Recommended)
```bash
ruby udsim2.rb [OPTIONS] project.xml task.xml [people.xml] [trend.xml]
```

### Using the Legacy Architecture
```bash
ruby lib/UDSim.rb [OPTIONS] project.xml trend.xml people.xml task.xml
```

### Example Run
```bash
cd run
./getdata.sh
```

## Command Line Options

Both architectures support similar options:

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output
- `-d, --debug` - Enable debug mode
- `-n, --num-sims=N` - Number of Monte Carlo simulations (default: 1)
- `-e, --seed=N` - Random seed for reproducible results
- `-g, --gantt=FILE` - Generate Gantt chart output
- `-s, --style=FACTOR` - Coding style factor (default: 1.0)

## Project Structure

```
udsim/
├── README.md           # Basic project information
├── udsim2.rb          # New architecture main script
├── lib/               # Legacy architecture components
│   ├── UDSim.rb       # Original main script
│   ├── Project.rb     # Legacy project model
│   ├── Person.rb      # Legacy person model
│   └── ...            # Other legacy components
├── src/               # New architecture components
│   ├── Design.rb      # Project design and job definitions
│   ├── WorkScheduler.rb # Task scheduling and simulation engine
│   ├── TaskManager.rb # Task lifecycle management
│   ├── People2.rb     # Simplified people management
│   └── ...            # Other new components
├── test/              # Test files and sample XML configurations
│   ├── test_*.rb      # Unit and integration tests
│   ├── project.xml    # Sample project definition
│   ├── task.xml       # Sample task type definitions
│   └── ...            # Other test data
└── data/              # Sample project datasets
```

## Architecture Overview

### New Architecture (src/)

**Core Components:**
- `Design.rb` - Parses project XML and creates job definitions with complexity metrics
- `WorkScheduler.rb` - Singleton that manages the simulation timeline and work distribution
- `TaskManager.rb` - Handles task lifecycle (pending → active → completed)
- `TaskPlan.rb` - Represents individual work units with effort estimates
- `TaskTypeConfig.rb` - Defines task types and their progression rules
- `People2.rb` / `Person2.rb` - Simplified person and team modeling

**Key Features:**
- Clean separation of concerns
- Improved modularity and testability
- Better support for dynamic task creation
- Enhanced Gantt chart generation

### Legacy Architecture (lib/)

**Core Components:**
- `UDSim.rb` - Main simulation engine with integrated logic
- `Project.rb` - Complex project modeling with dependencies
- `Person.rb` - Detailed person modeling with skills and communication
- `Timeline.rb` - Simulation timeline management
- `Task.rb` - Task definitions and execution

## Testing

### Run All Tests
```bash
# New architecture tests
ruby test/test_work_scheduler.rb
ruby test/test_design.rb  
ruby test/test_design_job_integration.rb
```

### Test Coverage
- **WorkScheduler Tests**: Core simulation engine functionality
- **Design Tests**: Project parsing and task creation
- **Integration Tests**: End-to-end workflow testing

## XML Configuration Files

### Project Definition (project.xml)
Defines jobs, their dependencies, and complexity metrics:
```xml
<project>
  <job name="fetch" inputs="2" outputs="1" instances="0">
    <complexity cyclo="5" loc="43"/>
  </job>
  <job name="execute" inputs="2" outputs="1" instances="0">
    <complexity cyclo="2" loc="72"/>
  </job>
</project>
```

### Task Types (task.xml)
Defines task progression and effort multipliers:
```xml
<task_types>
  <task_type name="start" effort="800" next="partition"/>
  <task_type name="partition" effort="180" next="design"/>
  <task_type name="design" effort="36" next="coding"/>
  <task_type name="coding" effort="36" next="verification"/>
  <task_type name="verification" effort="20" next=""/>
</task_types>
```

## Development Guidelines

### File Organization
- **New features**: Add to `src/` directory and update `udsim2.rb`
- **Legacy maintenance**: Modify `lib/` files for `UDSim.rb` compatibility
- **Tests**: Place in `test/` with appropriate require paths (`../src/` or `../lib/`)

### Common Development Tasks

**Adding New Task Types:**
1. Update task.xml configuration
2. Modify TaskTypeConfig.rb parsing if needed
3. Add tests in test_design.rb

**Extending Person Model:**
1. Modify Person2.rb for new architecture
2. Update People2.rb collection management
3. Add corresponding tests

**Simulation Enhancements:**
1. Update WorkScheduler.rb core logic
2. Modify TaskManager.rb for task handling
3. Test with test_work_scheduler.rb

### Running Simulations

**Single Simulation:**
```bash
ruby udsim2.rb test/project.xml test/task.xml
```

**Monte Carlo Analysis:**
```bash
ruby udsim2.rb -n 100 -e 42 test/project.xml test/task.xml
```

**With Gantt Chart:**
```bash
ruby udsim2.rb -g output.html test/project.xml test/task.xml
```

## Output Format

The simulator outputs statistical summaries:
```
time <average> <stddev> <max> <min>
effort <average> <stddev> <max> <min>
Tasks number <total> average_size <avg_effort>
```

Times are reported in 8-hour work days.

## Academic References

This simulator was used in:

1. "uDSim, a Microprocessor Design Time Simulation Infrastructure" - WACI/ASPLOS 2008
2. "A Design Time Simulator for Computer Architects" - ISQED 2011 (Best Paper Award)

## Notes

- The simulation uses Monte Carlo methods for statistical project analysis
- Both architectures support the same core XML configuration format
- Legacy architecture includes more complex person-to-person communication modeling
- New architecture focuses on cleaner code organization and maintainability