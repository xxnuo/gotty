package localcommand

import (
	"context"
	"os"
	"strings"
	"time"

	"github.com/KennethanCeyer/ptyx"
	"github.com/pkg/errors"
)

const (
	DefaultCloseTimeout = 10 * time.Second
)

type LocalCommand struct {
	command string
	argv    []string

	closeTimeout time.Duration

	session   ptyx.Session
	ptyClosed chan struct{}
}

func New(command string, argv []string, headers map[string][]string, options ...Option) (*LocalCommand, error) {
	env := append(os.Environ(), "TERM=xterm-256color")

	for key, values := range headers {
		h := "HTTP_" + strings.Replace(strings.ToUpper(key), "-", "_", -1) + "=" + strings.Join(values, ",")
		env = append(env, h)
	}

	opts := ptyx.SpawnOpts{
		Prog: command,
		Args: argv,
		Env:  env,
		Cols: 80,
		Rows: 24,
	}

	session, err := ptyx.Spawn(context.Background(), opts)
	if err != nil {
		return nil, errors.Wrapf(err, "failed to start command `%s`", command)
	}
	ptyClosed := make(chan struct{})

	lcmd := &LocalCommand{
		command: command,
		argv:    argv,

		closeTimeout: DefaultCloseTimeout,

		session:   session,
		ptyClosed: ptyClosed,
	}

	for _, option := range options {
		option(lcmd)
	}

	go func() {
		defer func() {
			lcmd.session.Close()
			close(lcmd.ptyClosed)
		}()

		lcmd.session.Wait()
	}()

	return lcmd, nil
}

func (lcmd *LocalCommand) Read(p []byte) (n int, err error) {
	return lcmd.session.PtyReader().Read(p)
}

func (lcmd *LocalCommand) Write(p []byte) (n int, err error) {
	return lcmd.session.PtyWriter().Write(p)
}

func (lcmd *LocalCommand) Close() error {
	lcmd.session.Kill()
	for {
		select {
		case <-lcmd.ptyClosed:
			return nil
		case <-lcmd.closeTimeoutC():
			lcmd.session.Kill()
		}
	}
}

func (lcmd *LocalCommand) WindowTitleVariables() map[string]interface{} {
	return map[string]interface{}{
		"command": lcmd.command,
		"argv":    lcmd.argv,
		"pid":     lcmd.session.Pid(),
	}
}

func (lcmd *LocalCommand) ResizeTerminal(width int, height int) error {
	return lcmd.session.Resize(width, height)
}

func (lcmd *LocalCommand) closeTimeoutC() <-chan time.Time {
	if lcmd.closeTimeout >= 0 {
		return time.After(lcmd.closeTimeout)
	}

	return make(chan time.Time)
}
