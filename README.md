# COBOL CI/CD Pipeline on IBM Z Xplore

Automated testing, compilation and execution of COBOL programs on an IBM Z Xplore Mainframe – triggered by every push to the `main` branch via GitHub Actions.

---

## What This Project Does

This pipeline bridges the gap between modern DevOps practices and classic mainframe development:

- Every Git push automatically runs **COBOL Check** unit tests on z/OS
- The generated test code is uploaded to the mainframe via SSH/Zowe
- A **JCL job** compiles and executes the program using the Enterprise COBOL Compiler
- All steps run **without manual intervention**

This is a real-world example of mainframe modernization: legacy COBOL code tested and deployed through a modern CI/CD pipeline.

---

## Programs in This Pipeline

| Program  | Lab   | Description                        |
|----------|-------|------------------------------------|
| NUMBERS  | Lab 1 | Numeric comparison operations      |
| EMPPAY   | Lab 2 | Employee payroll calculation       |
| DEPTPAY  | Lab 3 | Average department salary (TDD)    |

---

## Architecture Overview

```
GitHub Push
    │
    ▼
GitHub Actions Workflow (main.yml)
    │
    ├── Download COBOL Check v0.2.19
    ├── Install sshpass
    ├── zowe_operations.sh   → Upload files, EBCDIC conversion, configure environment
    └── mainframe_operations.sh → Run COBOL Check, submit JCL jobs on z/OS
```

---

## Repository Structure

```
cobol-check-automation/
  .github/
    workflows/
      main.yml                    # GitHub Actions Workflow
    scripts/
      zowe_operations.sh          # Upload & configuration (runs on GitHub Runner)
      mainframe_operations.sh     # COBOL Check & job submit (runs on z/OS)
  src/
    main/cobol/
      NUMBERS.CBL
      EMPPAY.CBL
      DEPTPAY.CBL
    test/cobol/
      NUMBERS/SymbolicRelationsTest.cut
      EMPPAY/EMPPAY.cut
      DEPTPAY/DEPTPAY.cut
  NUMBERS.JCL
  EMPPAY.JCL
  DEPTPAY.JCL
  .gitattributes                  # Enforces LF line endings (required for z/OS)
```

---

## Key Technical Challenges Solved

### 1. EBCDIC Encoding
z/OS uses EBCDIC (IBM-1047) instead of ASCII. All files uploaded via `scp` arrive as ASCII and must be converted:

```bash
iconv -f ISO8859-1 -t IBM-1047 $FILE > ${FILE}.tmp && mv ${FILE}.tmp $FILE
```

### 2. COBOL Check NullPointerException (Bug in v0.2.19)
`Platform.ZOS` is defined in COBOL Check but the launcher returns `null` at runtime.  
Discovered through **bytecode analysis with `javap -c`**.  
Workaround: `|| true` after the Java call – `CC##99.CBL` is still generated correctly.

### 3. No Key-Based SSH Authentication on Z Xplore
IBM Z Xplore does not support SSH key authentication.  
Solution: `sshpass` reading the password from an environment variable (never as a CLI argument):

```bash
export SSHPASS="$SSH_PASSWORD"
sshpass -e ssh -o StrictHostKeyChecking=no "${SSH_USERNAME}@${SSH_HOST}" ...
```

### 4. No `unzip` on z/OS
z/OS has no `unzip` command.  
Solution: Java's built-in `jar` tool:

```bash
/usr/lpp/java/J8.0_64/bin/jar xf cobol-check-0.2.19.zip
```

### 5. Shell Compatibility
z/OS uses `zsh` as default shell – no `bash`, no `sed -i`.  
All scripts use `#!/bin/sh` and are passed via `sh -s` (stdin) instead of being uploaded.

---

## GitHub Secrets Required

| Secret         | Description                        |
|----------------|------------------------------------|
| `SSH_HOST`     | IP address of the Z Xplore server  |
| `SSH_USERNAME` | Your Z Xplore user ID              |
| `SSH_PASSWORD` | Your Z Xplore password             |

Secrets are never written into scripts or YAML files directly.

---

## Test Results

COBOL Check generates a merged test program (`CC##99.CBL`) which is compiled and executed via JCL. Results appear in the JES2 SYSOUT:

```
      PASS:   1. Equal sign with literal compare
 **** FAIL:   2. Equal sign with literal compare (should fail)
     EXPECTED 000000000257500000
          WAS 000000000257400000

  60 TEST CASES WERE EXECUTED
  35 PASSED
  25 FAILED   ← all intentional (negative test cases)
```

Test cases marked `(should fail)` are **intentional negative tests** – they verify that COBOL Check correctly detects errors.

---

## What I Learned

- z/OS fundamentals: EBCDIC encoding, MVS datasets, JCL job submission via `submit`
- COBOL unit testing with COBOL Check (TDD approach)
- GitHub Actions: secrets management, workflow triggers, shell script execution on remote systems
- Debugging on z/OS: bytecode analysis, EBCDIC/ASCII issues, zsh compatibility
- CI/CD concepts applied to a mainframe environment

---

## Technologies Used

`COBOL` · `JCL` · `z/OS USS` · `GitHub Actions` · `COBOL Check` · `SSH` · `iconv` · `IBM Enterprise COBOL Compiler`

---

## Background

This project was built as part of my IBM Z Xplore learning journey, exploring how modern DevOps practices can be applied to mainframe development – a key aspect of mainframe modernization.

Full technical documentation available in: [`DOCUMENTATION.md`](DOCUMENTATION.md)
