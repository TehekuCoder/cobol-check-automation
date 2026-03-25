# COBOL CI/CD Pipeline on IBM Z Xplore with GitHub Actions

Technical Documentation  
March 2026

---

## 1. Overview

This documentation describes a CI/CD pipeline that automatically tests, compiles and executes COBOL programs on an IBM Z Xplore Mainframe – triggered by every push to the `main` branch in GitHub.

### Goal of the Pipeline

- Every Git push automatically tests COBOL programs using COBOL Check
- The generated test code is uploaded to the mainframe
- A JCL job compiles and executes the program on z/OS
- All steps run without manual intervention

### Programs in This Pipeline

| Program | Lab   | Description                          |
|---------|-------|--------------------------------------|
| NUMBERS | Lab 1 | Numeric comparison operations        |
| EMPPAY  | Lab 2 | Employee payroll calculation         |
| DEPTPAY | Lab 3 | Average department salary (TDD)      |

---

## 2. Repository Structure

The repository follows a clear directory structure containing both the GitHub Actions workflow and the COBOL source files:

```
cobol-check-automation/
  .github/
    workflows/
      main.yml                      # GitHub Actions Workflow
    scripts/
      zowe_operations.sh            # Upload & configuration
      mainframe_operations.sh       # COBOL Check & job submit
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
  .gitattributes                    # Enforces LF line endings
```

> **Note:** The `.gitattributes` file is critical – it ensures that all text files are stored with Unix line endings (LF), which is mandatory for z/OS.

---

## 3. GitHub Actions Workflow (main.yml)

The workflow is triggered on every push to `main` or manually via `workflow_dispatch`. It consists of four steps:

### 3.1 Steps Overview

| # | Step | What happens |
|---|------|--------------|
| 1 | Download COBOL Check | COBOL Check ZIP (v0.2.19) is downloaded from GitHub |
| 2 | Set up sshpass | sshpass is installed for non-interactive SSH connections |
| 3 | Upload to Mainframe | `zowe_operations.sh` uploads all files and configures the environment |
| 4 | Run COBOL Check | `mainframe_operations.sh` runs directly on z/OS via `ssh ... 'sh -s'` |

### 3.2 GitHub Secrets

Three secrets must be stored in the repository settings (Settings → Secrets → Actions):

| Secret | Content |
|--------|---------|
| `SSH_HOST` | `204.90.115.200` – IP of the Z Xplore server |
| `SSH_USERNAME` | Your Z Xplore user ID |
| `SSH_PASSWORD` | Your Z Xplore password |

> **Important:** Never write secrets directly into scripts or YAML files. GitHub automatically masks them as `***` and they are only available at runtime.

### 3.3 SSH Connection with Password

IBM Z Xplore does not support key-based SSH authentication. Instead, `sshpass` is used:

```bash
export SSHPASS="$SSH_PASSWORD"
sshpass -e ssh -o StrictHostKeyChecking=no \
  "${SSH_USERNAME}@${SSH_HOST}" \
  "SSH_USERNAME=${SSH_USERNAME} sh -s" \
  < .github/scripts/mainframe_operations.sh
```

The `-e` flag instructs sshpass to read the password from the environment variable `$SSHPASS` – never as an argument that would be visible in process lists. The `sh -s` trick passes the local script as input to the remote shell without uploading it.

---

## 4. zowe_operations.sh – Upload & Configuration

This script runs locally on the GitHub Actions Runner (Ubuntu) and prepares the mainframe. It is executed once per pipeline run.

### 4.1 What the Script Does

- Create directories on the mainframe (`mkdir -p`)
- Upload the COBOL Check ZIP and extract it with `jar xf`
- Upload COBOL source files, test suites and JCL files
- Convert all uploaded files from ASCII to EBCDIC
- Generate the `zos_run_tests` script directly on the mainframe
- Configure `config.properties` for z/OS

### 4.2 EBCDIC Conversion

This is the most critical step. z/OS uses EBCDIC as its character encoding – all files uploaded from Linux via `scp` arrive as ASCII and must be converted:

```bash
for FILE in \
  ${REMOTE_DIR}/src/main/cobol/NUMBERS.CBL \
  ${REMOTE_DIR}/NUMBERS.JCL ...; do
  iconv -f ISO8859-1 -t IBM-1047 $FILE > ${FILE}.tmp \
    && mv ${FILE}.tmp $FILE
done
```

> **Note:** The conversion must happen AFTER the upload, not before. Also, `config.properties` must not be recreated – it already comes in EBCDIC from the ZIP.

### 4.3 config.properties Configuration

COBOL Check reads its configuration from `config.properties`. Two adjustments are needed for z/OS:

```bash
# Change cobolcheck.test.program.path from ./testruns to ./
iconv -f IBM-1047 -t ISO8859-1 config.properties |
  sed 's|test.program.path = ./testruns|test.program.path = ./|' |
  iconv -f ISO8859-1 -t IBM-1047 > config_new.properties

# Point linux.process to our own script
echo 'linux.process = zos_run_tests' |
  iconv -f ISO8859-1 -t IBM-1047 >> config.properties
```

> **Why `linux.process` instead of `zos.process`?** A bug in COBOL Check 0.2.19 – `Platform.ZOS` is defined in the code but the launcher returns `null`. Discovered through bytecode analysis with `javap -c`.

---

## 5. mainframe_operations.sh – Execution on z/OS

This script runs directly on the IBM Z Xplore server. It is passed via `ssh ... 'sh -s' < script.sh` – no upload needed, the shell reads it from stdin.

### 5.1 Shebang and Shell

The script starts with `#!/bin/sh` – not bash. z/OS has no bash, and zsh has different syntax rules that cause parsing errors.

### 5.2 run_cobolcheck Function

A shell function processes each program in sequence:

```sh
run_cobolcheck() {
  PROGRAM=$1

  # Run COBOL Check (|| true due to known z/OS bug)
  java -jar ${REMOTE_DIR}/bin/cobol-check-0.2.19.jar \
    -p "${PROGRAM}" || true

  # Copy CC##99.CBL to MVS Dataset
  cp "testruns/CC##99.CBL" "//'${SSH_USERNAME}.CBL(${PROGRAM})'"

  # Submit JCL job directly from USS
  submit "${PROGRAM}.JCL"
}

run_cobolcheck NUMBERS
run_cobolcheck EMPPAY
run_cobolcheck DEPTPAY
```

### 5.3 The `|| true` Trick

COBOL Check always throws a `NullPointerException` on z/OS at the end – an unimplemented launcher for `Platform.ZOS`. The `|| true` prevents this error from aborting the pipeline. `CC##99.CBL` is still generated correctly.

### 5.4 Job Submit

The `submit` command is a z/OS USS command that passes a JCL file directly to JES2. The file must be in EBCDIC – hence the conversion in `zowe_operations.sh`.

```sh
submit "${PROGRAM}.JCL"
# Output: JOB JOB00330 submitted from path 'NUMBERS.JCL'
```

---

## 6. COBOL Check on z/OS

### 6.1 What COBOL Check Does

COBOL Check reads the test suite (`.cut` file) and the COBOL source code, merges them into a new COBOL program (`CC##99.CBL`) and compiles/executes it. The generated program contains the original code plus the test framework code.

### 6.2 Directory Structure on the Mainframe

```
/z/z88469/cobolcheck/
  bin/
    cobol-check-0.2.19.jar        # COBOL Check JAR
  scripts/
    linux_gnucobol_run_tests      # Original (not used)
    zos_run_tests                 # Our own script
  src/
    main/cobol/NUMBERS.CBL, EMPPAY.CBL, DEPTPAY.CBL
    test/cobol/
      NUMBERS/SymbolicRelationsTest.cut
      EMPPAY/EMPPAY.cut
      DEPTPAY/DEPTPAY.cut
  testruns/
    CC##99.CBL                    # Generated test code
  config.properties
  NUMBERS.JCL, EMPPAY.JCL, DEPTPAY.JCL
```

### 6.3 Interpreting Test Results

Test results appear in the SYSOUT of the JCL job. Tests with `(should fail)` in their name are intentionally failing – they verify that COBOL Check correctly detects errors:

```
      PASS:   1. Equal sign with literal compare
 **** FAIL:   2. Equal sign with literal compare (should fail)
     EXPECTED 000000000257500000
          WAS 000000000257400000

  60 TEST CASES WERE EXECUTED
  35 PASSED
  25 FAILED   ← all intentional
```

---

## 7. JCL Files

Each program has its own JCL file that performs two steps: compilation with the Enterprise COBOL Compiler and execution of the program.

### 7.1 Structure (Example: NUMBERS.JCL)

```jcl
//NUMBERSJ JOB 1,NOTIFY=&SYSUID
//COBRUN  EXEC IGYWCL
//COBOL.SYSIN  DD DSN=&SYSUID..CBL(NUMBERS),DISP=SHR
//LKED.SYSLMOD DD DSN=&SYSUID..LOAD(NUMBERS),DISP=SHR
// IF RC = 0 THEN
//RUN      EXEC PGM=NUMBERS
//STEPLIB  DD DSN=&SYSUID..LOAD,DISP=SHR
//SYSOUT   DD SYSOUT=*,OUTLIM=15000
//CEEDUMP  DD DUMMY
//SYSUDUMP DD DUMMY
// ELSE
//SKIP     EXEC PGM=IEFBR14
// ENDIF
```

### 7.2 Return Codes

| Return Code | Meaning |
|-------------|---------|
| CC 0000 | Compilation and execution successful |
| CC 0004 | Informational messages (warnings) – program still runs |
| CC 0008 | Warnings that should be addressed |
| CC 0012+ | Errors – compilation failed |

---

## 8. Known Issues & Solutions

### 8.1 EBCDIC vs ASCII
**Symptom:** Garbled characters in files, `zsh parse error`, `No such file or directory` even though file exists.  
**Cause:** z/OS stores text in EBCDIC (IBM-1047). Files uploaded via `scp` arrive as ASCII.  
**Solution:** `iconv -f ISO8859-1 -t IBM-1047` after every upload.

### 8.2 COBOL Check NullPointerException
**Symptom:** `Exception in thread 'main' java.lang.NullPointerException at LauncherController.runTestProgram`  
**Cause:** `Platform.ZOS` is not implemented in COBOL Check 0.2.19 – the launcher returns `null`. Discovered through bytecode analysis with `javap -c`.  
**Solution:** `|| true` after the `java` call. `CC##99.CBL` is still generated correctly.

### 8.3 JCL Truncation Error
**Symptom:** `cp: FSUM6260 write error: EDC5003I Truncation of a record`  
**Cause:** The JCL file is in ASCII instead of EBCDIC.  
**Solution:** EBCDIC conversion of JCL in `zowe_operations.sh`, then `submit` instead of `cp` for job submission.

### 8.4 zsh Parse Error near `|`
**Symptom:** `zsh: FSUZ0202 unmatched backtick` or `parse error near '|'`  
**Cause:** Scripts uploaded via `scp` contain Windows line endings (CRLF) or wrong encoding.  
**Solution:** `.gitattributes` with `*.sh text eol=lf`, and execute `mainframe_operations.sh` via `sh -s` instead of uploading.

### 8.5 `unzip` Not Available
**Symptom:** `FSUZ0085 command not found: unzip`  
**Cause:** z/OS has no `unzip` command.  
**Solution:** `/usr/lpp/java/J8.0_64/bin/jar xf file.zip` – Java's jar tool can extract ZIP files.

---

## 9. CI/CD Concepts

### 9.1 What is CI/CD?

**Continuous Integration (CI):** Every code push is automatically built and tested.  
**Continuous Delivery (CD):** The tested code is automatically delivered.

| Term | Meaning in This Project |
|------|------------------------|
| Trigger | Git push to `main` starts the pipeline automatically |
| Build | COBOL Check generates `CC##99.CBL` |
| Test | JCL job compiles and executes the test code |
| Deploy | Compiled program lands in `Z88469.LOAD` |

### 9.2 Important Shell Concepts

- `set -euo pipefail` – `-e` stops on errors, `-u` on unset variables, `-o pipefail` when a pipe fails
- `: "${VAR:?ERROR}"` – checks if a variable is set, exits with error message if not
- Heredoc `<< EOF` – passes multiple lines as input to a command
- **Idempotency** – scripts that can be run multiple times without causing damage (`mkdir -p`, `rm -f` before recreation)
- `|| true` – prevents a failed command from stopping the script

---

## 10. Key Learnings

### z/OS Specifics
- EBCDIC encoding is the most fundamental difference from Linux/Windows
- z/OS uses `zsh` as default shell – no bash, no unzip, no `sed -i`
- MVS datasets have fixed record formats – files must be in the correct encoding
- `submit` is the native way to submit JCL jobs from USS

### COBOL Check
- COBOL Check generates test code that is embedded into the original COBOL code
- `Platform.ZOS` is not implemented in v0.2.19 – a real open source bug
- `config.properties` comes in EBCDIC from the ZIP and must not be recreated
- Test cases with `(should fail)` are intentional errors for testing the framework

### GitHub Actions
- Secrets are masked as `***` and are only available at runtime
- `$GITHUB_WORKSPACE` always points to the repository directory of the runner
- `actions/checkout@v4` is the current version – v2 runs on outdated Node.js
- `workflow_dispatch` enables manual triggering via the GitHub UI

---

*End of Documentation*
