# Coding Conventions

"Callable" labels - i.e. addresses of functions which will end in a ret code - are in lowercase

Other labels, including jump addresses and data labels are in uppercase

Private labels - those which should not be referenced outside of their file are prepending with an underscore

# Build / Structural Conventions

Build targets are independent - if the same function is present in multiple targets, it may not have the same address

Attempting to coerce the targets to share the same entry points may be convenient for external programs, but it adds significant complexity to the code, making it less reliable, and will bloat the targets, especially if additional targets are added. Using ALIGN directives to pad between functions and reduce churn may be done but is not required (it is of limited value and will add bloat)