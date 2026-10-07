//go:build unix

package entrypoint

import (
	"errors"
	"flag"
	"fmt"
	"net/http/cgi"
	"net/http/httptest"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/rogpeppe/go-internal/testscript"
)

const (
	fakeLogEnv  = "FAKE_IMAPFILTER_LOG"
	fakeModeEnv = "FAKE_IMAPFILTER_MODE"

	// fakeBlockTimeout bounds a blocking fake if orphan detection fails.
	fakeBlockTimeout = 30 * time.Second

	// fakeOrphanInterval is how often a blocking fake checks if its parent died.
	fakeOrphanInterval = 50 * time.Millisecond

	waitforTimeout  = 10 * time.Second
	waitforInterval = 50 * time.Millisecond
)

var fakeStartRe = regexp.MustCompile(`(?m)^start pid=(\d+) `)

func TestMain(m *testing.M) {
	testscript.Main(m, map[string]func(){
		"imapfilter": func() { os.Exit(runFakeImapfilter()) },
	})
}

func TestEntrypoint(t *testing.T) {
	t.Parallel()

	entrypoint, err := filepath.Abs("entrypoint.sh")
	if err != nil {
		t.Fatal(err)
	}

	testscript.Run(t, testscript.Params{
		Dir:                 "testdata/script",
		RequireExplicitExec: true,
		UpdateScripts:       os.Getenv("UPDATE") != "",
		Setup: func(env *testscript.Env) error {
			env.Setenv("ENTRYPOINT", entrypoint)
			env.Setenv("IMAPFILTER_CONFIG_BASE", filepath.Join(env.WorkDir, "config"))
			env.Setenv("IMAPFILTER_SLEEP", "0.1")
			env.Setenv(fakeLogEnv, filepath.Join(env.WorkDir, "imapfilter.log"))
			env.Setenv("GIT_CONFIG_NOSYSTEM", "1")
			env.Setenv("GIT_CONFIG_GLOBAL", os.DevNull)
			env.Setenv("GIT_TERMINAL_PROMPT", "0")
			return nil
		},
		Cmds: map[string]func(*testscript.TestScript, bool, []string){
			"waitfor":   cmdWaitfor,
			"alive":     cmdAlive,
			"gitserve":  cmdGitserve,
			"gitcommit": cmdGitcommit,
		},
	})
}

// runFakeImapfilter logs its start to $FAKE_IMAPFILTER_LOG and behaves per $FAKE_IMAPFILTER_MODE.
// Modes: exit0 (default), exit1, block (until SIGTERM or orphaned).
func runFakeImapfilter() int {
	// registered before logging start so scripts may signal once start is logged
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGTERM)
	ppid := os.Getppid()

	flags := flag.NewFlagSet("imapfilter", flag.ContinueOnError)
	config := flags.String("c", "", "config file")
	logfile := flags.String("l", "", "log file")
	if err := flags.Parse(os.Args[1:]); err != nil {
		return 2
	}

	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}

	if err := fakeLog("start pid=%d cwd=%s config=%s log=%s", os.Getpid(), cwd, *config, *logfile); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}

	switch mode := os.Getenv(fakeModeEnv); mode {
	case "", "exit0":
		return 0
	case "exit1":
		return 1
	case "block":
		return fakeBlock(sigs, ppid)
	default:
		fmt.Fprintf(os.Stderr, "unknown %s %q\n", fakeModeEnv, mode)
		return 2
	}
}

// fakeBlock waits for SIGTERM.
// Exits early when orphaned since an orphan holds the killed entrypoint's
// output pipe open and blocks the script's wait.
func fakeBlock(sigs <-chan os.Signal, ppid int) int {
	orphanTick := time.NewTicker(fakeOrphanInterval)
	defer orphanTick.Stop()
	timeout := time.After(fakeBlockTimeout)
	for {
		select {
		case <-sigs:
			if err := fakeLog("term pid=%d", os.Getpid()); err != nil {
				fmt.Fprintln(os.Stderr, err)
				return 2
			}
			return 0
		case <-orphanTick.C:
			if os.Getppid() != ppid {
				return 1
			}
		case <-timeout:
			return 1
		}
	}
}

func fakeLog(format string, args ...any) error {
	f, err := os.OpenFile(os.Getenv(fakeLogEnv), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("opening fake log: %w", err)
	}
	if _, err := fmt.Fprintf(f, format+"\n", args...); err != nil {
		f.Close()
		return fmt.Errorf("writing fake log: %w", err)
	}
	if err := f.Close(); err != nil {
		return fmt.Errorf("closing fake log: %w", err)
	}
	return nil
}

// fakePIDs returns the PIDs of all fake starts in order.
func fakePIDs(logPath string) ([]int, error) {
	b, err := os.ReadFile(logPath)
	if err != nil {
		return nil, fmt.Errorf("reading fake log: %w", err)
	}
	var pids []int
	for _, m := range fakeStartRe.FindAllSubmatch(b, -1) {
		pid, err := strconv.Atoi(string(m[1]))
		if err != nil {
			return nil, fmt.Errorf("parsing pid: %w", err)
		}
		pids = append(pids, pid)
	}
	return pids, nil
}

// cmdWaitfor polls file until regexp matches count times.
// usage: waitfor file regexp [count]
func cmdWaitfor(ts *testscript.TestScript, neg bool, args []string) {
	if neg || len(args) < 2 || len(args) > 3 {
		ts.Fatalf("usage: waitfor file regexp [count]")
	}
	re, err := regexp.Compile("(?m)" + args[1])
	ts.Check(err)
	count := 1
	if len(args) == 3 {
		count, err = strconv.Atoi(args[2])
		ts.Check(err)
	}

	path := ts.MkAbs(args[0])
	deadline := time.Now().Add(waitforTimeout)
	for {
		b, err := os.ReadFile(path)
		if err == nil && len(re.FindAll(b, -1)) >= count {
			return
		}
		if time.Now().After(deadline) {
			ts.Fatalf("timed out after %s waiting for %d matches of %q in %s", waitforTimeout, count, args[1], args[0])
		}
		time.Sleep(waitforInterval)
	}
}

// cmdAlive checks if the nth (1-based) logged fake has not been reaped yet, zombies included.
// usage: alive n
func cmdAlive(ts *testscript.TestScript, neg bool, args []string) {
	if len(args) != 1 {
		ts.Fatalf("usage: alive n")
	}
	n, err := strconv.Atoi(args[0])
	ts.Check(err)
	pids, err := fakePIDs(ts.Getenv(fakeLogEnv))
	ts.Check(err)
	if n < 1 || n > len(pids) {
		ts.Fatalf("fake %d not logged, have %d", n, len(pids))
	}

	pid := pids[n-1]
	// always succeeds on unix
	proc, err := os.FindProcess(pid)
	ts.Check(err)
	err = proc.Signal(syscall.Signal(0))
	if err != nil && !errors.Is(err, os.ErrProcessDone) {
		ts.Fatalf("probing fake %d (pid %d): %v", n, pid, err)
	}
	alive := err == nil
	if alive && neg {
		ts.Fatalf("fake %d (pid %d) is alive", n, pid)
	}
	if !alive && !neg {
		ts.Fatalf("fake %d (pid %d) is not alive", n, pid)
	}
}

// cmdGitserve commits dir as a git repository, serves it over smart HTTP
// and points GIT_TARGET and GIT_TOKEN_RAW at it.
// usage: gitserve dir
func cmdGitserve(ts *testscript.TestScript, neg bool, args []string) {
	if neg || len(args) != 1 {
		ts.Fatalf("usage: gitserve dir")
	}
	dir := ts.MkAbs(args[0])
	runGit(ts, dir, "init", "-q", "-b", "main")
	gitCommitAll(ts, dir, "init")

	backend := filepath.Join(strings.TrimSpace(runGit(ts, dir, "--exec-path")), "git-http-backend")
	if _, err := os.Stat(backend); err != nil {
		ts.Fatalf("git-http-backend required: %v", err)
	}
	srv := httptest.NewServer(&cgi.Handler{
		Path: backend,
		Env: []string{
			"GIT_PROJECT_ROOT=" + filepath.Dir(dir),
			"GIT_HTTP_EXPORT_ALL=1",
			"GIT_CONFIG_NOSYSTEM=1",
			"GIT_CONFIG_GLOBAL=" + os.DevNull,
		},
	})
	ts.Defer(srv.Close)

	ts.Setenv("GIT_TARGET", srv.URL+"/"+filepath.Base(dir)+"/.git")
	ts.Setenv("GIT_TOKEN_RAW", "token")
}

// cmdGitcommit commits all changes in dir.
// usage: gitcommit dir
func cmdGitcommit(ts *testscript.TestScript, neg bool, args []string) {
	if neg || len(args) != 1 {
		ts.Fatalf("usage: gitcommit dir")
	}
	gitCommitAll(ts, ts.MkAbs(args[0]), "update")
}

func gitCommitAll(ts *testscript.TestScript, dir, msg string) {
	runGit(ts, dir, "add", "-A")
	runGit(ts, dir,
		"-c", "user.name=test",
		"-c", "user.email=test@example.com",
		"-c", "commit.gpgsign=false",
		"commit", "-q", "-m", msg,
	)
}

func runGit(ts *testscript.TestScript, dir string, args ...string) string {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"HOME="+ts.Getenv("HOME"),
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_CONFIG_GLOBAL="+os.DevNull,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		ts.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
	}
	return string(out)
}
