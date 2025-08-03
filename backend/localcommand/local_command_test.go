package localcommand

import (
	"bytes"
	"reflect"
	"testing"
	"time"
)

func TestNewFactory(t *testing.T) {
	factory, err := NewFactory("/bin/false", []string{}, &Options{CloseTimeout: 321})
	if err != nil {
		t.Errorf("NewFactory() returned error")
		return
	}
	if factory.command != "/bin/false" {
		t.Errorf("factory.command = %v, expected %v", factory.command, "/bin/false")
	}
	if !reflect.DeepEqual(factory.argv, []string{}) {
		t.Errorf("factory.argv = %v, expected %v", factory.argv, []string{})
	}
	if !reflect.DeepEqual(factory.options, &Options{CloseTimeout: 321}) {
		t.Errorf("factory.options = %v, expected %v", factory.options, &Options{})
	}

	slave, _ := factory.New(nil, nil)
	lcmd := slave.(*LocalCommand)
	if lcmd.closeTimeout != time.Second*321 {
		t.Errorf("lcmd.closeTimeout = %v, expected %v", lcmd.closeTimeout, time.Second*321)
	}
}

func TestFactoryNew(t *testing.T) {
	factory, err := NewFactory("/bin/cat", []string{}, &Options{})
	if err != nil {
		t.Errorf("NewFactory() returned error")
		return
	}

	slave, err := factory.New(nil, nil)
	if err != nil {
		t.Errorf("factory.New() returned error")
		return
	}

	writeBuf := []byte("foobar\n")
	n, err := slave.Write(writeBuf)
	if err != nil {
		t.Errorf("write() failed: %v", err)
		return
	}
	if n != 7 {
		t.Errorf("Unexpected write length. n = %d, expected n = %d", n, 7)
		return
	}

	expectedBuf := []byte("foobar\r\nfoobar\r\n")
	readBuf := make([]byte, 1024)
	var totalRead int
	for totalRead < 16 {
		n, err = slave.Read(readBuf[totalRead:])
		if err != nil {
			t.Errorf("read() failed: %v", err)
			return
		}
		totalRead += n
	}
	if totalRead != 16 {
		t.Errorf("Unexpected read length. totalRead = %d, expected totalRead = %d", totalRead, 16)
		return
	}
	if !bytes.Equal(readBuf[:totalRead], expectedBuf) {
		t.Errorf("unexpected output from slave: got %v, expected %v", readBuf[:totalRead], expectedBuf)
	}
	err = slave.Close()
	if err != nil {
		t.Errorf("close() failed: %v", err)
		return
	}

}
