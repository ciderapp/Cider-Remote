//
//  Cider_RemoteApp.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

@main
struct Cider_RemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate: AppDelegate

    static var delegate: AppDelegate = .shared

	@State private var onboarded: Bool = false

    var body: some Scene {
        WindowGroup {
			ZStack {
				if onboarded {
					ContentView()
				} else {
					OnboardingView()
				}
			}
			.onAppear {
				Self.delegate = self.delegate
				RemoteShortcuts.updateAppShortcutParameters()

				self.onboarded = UserDefaults.standard.value(forKey: "onboarded") != nil ? UserDefaults.standard.bool(forKey: "onboarded") : false
			}
        }
    }
}
