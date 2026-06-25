// File: MalfunctionDZ/Services/AppBranding.swift
import Foundation

enum AppBranding {
    /// Asset catalog image name for the login screen logo.
    static var loginLogoName: String {
        #if ASC_PILOTS
        "ASCPilotsLogo"
        #elseif ASC_STAFF
        "ASCStaffLogo"
        #elseif ASC_PACKERS
        "ASCPackersLogo"
        #elseif ASC_STUDENTS
        "ASCStudentsLogo"
        #else
        "MalfunctionDZLogo"
        #endif
    }
}
