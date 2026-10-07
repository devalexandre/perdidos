package settings

import "testing"

func TestFolderIDFromURL(t *testing.T) {
	for in, want := range map[string]string{
		"https://drive.google.com/drive/folders/178ylieiRtCYsOtrr-8wTmd2hB3oymsNW?usp=drive_link": "178ylieiRtCYsOtrr-8wTmd2hB3oymsNW",
		"178ylieiRtCYsOtrr-8wTmd2hB3oymsNW":                                "178ylieiRtCYsOtrr-8wTmd2hB3oymsNW",
		"https://drive.google.com/embeddedfolderview?id=abcDEF_123-x#list": "abcDEF_123-x",
		"-": "",
	} {
		if got := FolderIDFromURL(in); got != want {
			t.Errorf("%s: %q", in, got)
		}
	}
}

func TestRootOverride(t *testing.T) {
	t.Setenv("PERDIDOS_HOME", "/tmp/x")
	if Root() != "/tmp/x" {
		t.Fatal(Root())
	}
}
