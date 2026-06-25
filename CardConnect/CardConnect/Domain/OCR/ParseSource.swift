// ParseSource.swift
// CardConnect
// Android Cat-9: tek VCardParser, iki kaynak — duplicate impl yasak.

import Foundation

enum ParseSource {
    case string(String)
    case file(URL)
}
