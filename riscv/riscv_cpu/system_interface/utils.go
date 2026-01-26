package systeminterface

import (
	"strconv"
	"strings"
)

func padLeft(s string, length int) string {
	if len(s) >= length {
		return s
	}
	return strings.Repeat("0", length-len(s)) + s
}

func ToHexString(value uint64, length int) string {
	return "0x" + padLeft(strconv.FormatUint(value, 16), length)
}

func ToBinString(value uint64, length int) string {
	return "0b" + padLeft(strconv.FormatUint(value, 2), length)
}
