//
//  ViewController.swift
//  WHIPCoder
//
//  Created by dimiden on 5/7/24.
//

import UIKit
import WebRTC

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    private let logger: Logger = .init(MainViewController.self)
    @IBOutlet var urlTextField: UITextField!
    @IBOutlet var startButton: UIButton!
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var tableView: UITableView!

    let mediaFileNames = Settings.shared.availableMediaFileNames()
    let videoCodecInfos = Settings.shared.availableVideoCodecInfos()
    let framerates = Settings.shared.availableFramerates()
    let videoResolutions = Settings.shared.availableCameraResolutions()

    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewWasTapped))
        view.addGestureRecognizer(tapGesture)
        tapGesture.cancelsTouchesInView = false

        urlTextField.addTarget(self, action: #selector(endpointUrlWasChanged), for: .editingChanged)
        urlTextField.text = Settings.shared.endpointUrl
        startButton.isEnabled = (Settings.shared.endpointUrl.isEmpty == false)
    }

    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func updateStartButton() {
        let settings = Settings.shared

        startButton.isEnabled =
            (settings.endpointUrl.isEmpty == false) &&
            (settings.videoCodecInfo != nil) &&
            (settings.resolution != nil)
    }

    // MARK: - Event handlers

    // Called by UITapGestureRecognizer of self.view
    @objc private func viewWasTapped(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    // Called by self.urlTextField
    @objc func endpointUrlWasChanged(_ sender: UITextField) {
        DispatchQueue.main.async {
            Settings.shared.endpointUrl = sender.text ?? ""
            self.startButton.isEnabled = (Settings.shared.endpointUrl.isEmpty == false)
        }
    }

    @objc func bframeSwitchChanged(sender: UISwitch) {
        DispatchQueue.main.async {
            Settings.shared.useBframe = sender.isOn
            self.tableView.reloadData()
        }
    }

    func codecChanged(index: Int) {
        DispatchQueue.main.async {
            Settings.shared.videoCodecInfo = self.videoCodecInfos[index]
            self.tableView.reloadData()
        }
    }

    func framerateChanged(index: Int) {
        DispatchQueue.main.async {
            Settings.shared.framerate = self.framerates[index]
            self.tableView.reloadData()
        }
    }

    func mediaFileChanged(index: Int) {
        DispatchQueue.main.async {
            Settings.shared.mediaFileName = self.mediaFileNames[index]
            self.tableView.reloadData()
        }
    }

    @objc func bitrateChanged(sender: UITextField) {
        DispatchQueue.main.async {
            Settings.shared.videoBitrate = ((sender.text != nil) ? Int32(sender.text!) : nil) ?? Settings.shared.videoBitrate
            self.tableView.reloadData()
        }
    }

    func resolutionChanged(index: Int) {
        DispatchQueue.main.async {
            Settings.shared.resolution = self.videoResolutions[index]
            self.tableView.reloadData()
        }
    }

    // MARK: - Keyboard event handlers

    func keyboardNotificationInfo(_ notification: Notification) -> (
        Double, UIView.AnimationOptions, CGRect
    )? {
        let info = notification.userInfo

        if let duration = info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
           let curve = info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
           let frame = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        {
            return (duration, UIView.AnimationOptions(rawValue: curve << 16), frame)
        }

        return nil
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let (duration, options, frame) = keyboardNotificationInfo(notification) {
            let height = frame.height - view.safeAreaInsets.bottom
            tableViewBottomConstraint.constant = height + 10
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        if let (duration, options, _) = keyboardNotificationInfo(notification) {
            tableViewBottomConstraint.constant = 0
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                self.view.layoutIfNeeded()
            }
        }
    }

    // MARK: - TableView

    enum Sections: CaseIterable {
        case bframe
        case codec
        case bitrate
        case framerate
        case mediaFile
        case resolution
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        // Exclude Sections.resolution - this is only valid when using an actual camera
        return Sections.allCases.count - 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return switch Sections.allCases[section] {
        case .bframe: "B-frame"
        case .codec: "Video codec"
        case .bitrate: "Maximum bitrate (Kbps)"
        case .framerate: "Framerate"
        case .mediaFile: "Target video file"
        case .resolution: "Video resolution"
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return switch Sections.allCases[section] {
        case .bframe: 1
        case .codec: videoCodecInfos.count
        case .bitrate: 1
        case .framerate: framerates.count
        case .mediaFile: mediaFileNames.count
        case .resolution: videoResolutions.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Sections.allCases[indexPath.section]
        let settings = Settings.shared

        switch section {
        case .bframe:
            return tableViewCellSwitch(
                tableView: tableView, cellForRowAt: indexPath,
                title: "Enable b-frame for H.264/H.265",
                isOn: settings.useBframe,
                action: #selector(bframeSwitchChanged)
            )

        case .codec:
            let codecInfo = videoCodecInfos[indexPath.row]
#if RTC_ENABLE_BFRAME
            return tableViewCellNormal(
                tableView: tableView, cellForRowAt: indexPath,
                title: ({ codecInfo.codecInfoString() })(),
                isChecked: settings.videoCodecInfo?.isEqual(toCodecInfoWithoutBframe: codecInfo) ?? false
            )
#else // RTC_ENABLE_BFRAME
            return tableViewCellNormal(
                tableView: tableView, cellForRowAt: indexPath,
                title: ({ codecInfo.codecInfoString() })(),
                isChecked: settings.videoCodecInfo?.isEqual(to: codecInfo) ?? false
            )
#endif // RTC_ENABLE_BFRAME

        case .bitrate:
            return tableViewCellTextField(
                tableView: tableView, cellForRowAt: indexPath,
                placeholder: "Enter max bitrate (Kbps)",
                value: "\(settings.videoBitrate)",
                action: #selector(bitrateChanged)
            )

        case .framerate:
            let framerate = framerates[indexPath.row]
            return tableViewCellNormal(
                tableView: tableView, cellForRowAt: indexPath,
                title: "\(framerate)",
                isChecked: framerate == settings.framerate
            )

        case .mediaFile:
            let mediaFileName = mediaFileNames[indexPath.row]
            return tableViewCellNormal(
                tableView: tableView, cellForRowAt: indexPath,
                title: "\(mediaFileName)",
                isChecked: mediaFileName == settings.mediaFileName
            )

        case .resolution:
            let res = videoResolutions[indexPath.row]
            return tableViewCellNormal(
                tableView: tableView, cellForRowAt: indexPath,
                title: res.resolutionString(),
                isChecked: res.isEquals(settings.resolution)
            )
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40.0
    }

    func tableViewCell(
        withIdentifier identifier: String,
        tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier) else {
            return UITableViewCell(style: .default, reuseIdentifier: identifier)
        }

        return cell
    }

    func tableViewCellNormal(
        tableView: UITableView, cellForRowAt indexPath: IndexPath,
        title: String, isChecked: Bool
    ) -> UITableViewCell {
        let cell = tableViewCell(withIdentifier: "NormalCellIdentifier", tableView: tableView, cellForRowAt: indexPath)

        cell.textLabel?.text = title
        cell.accessoryType = isChecked ? .checkmark : .none

        return cell
    }

    func tableViewCellSwitch(
        tableView: UITableView, cellForRowAt indexPath: IndexPath,
        title: String, isOn: Bool, action: Selector
    ) -> UITableViewCell {
        let cell = tableViewCell(withIdentifier: "CellWithSwitchIdentifier", tableView: tableView, cellForRowAt: indexPath)

        let switchView = (cell.accessoryView as? UISwitch)!
        switchView.removeTarget(nil, action: nil, for: .allEvents)
        switchView.addTarget(action, action: action, for: .valueChanged)
        switchView.isOn = isOn

        cell.textLabel?.text = title

        return cell
    }

    @objc func tableViewCellTextFieldDidEndEditing() {
        view.endEditing(true)
    }

    func tableViewCellTextField(
        tableView: UITableView, cellForRowAt indexPath: IndexPath,
        placeholder: String, value: String, action: Selector
    ) -> UITableViewCell {
        let cell = tableViewCell(withIdentifier: "CellWithTextFieldIdentifier", tableView: tableView, cellForRowAt: indexPath)

        let textField = cell.contentView.viewWithTag(150) as! UITextField

        textField.text = value
        textField.placeholder = placeholder
        textField.removeTarget(nil, action: nil, for: .allEvents)
        textField.addTarget(self, action: action, for: .editingDidEnd)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Sections.allCases[indexPath.section] {
        case .codec:
            codecChanged(index: indexPath.row)

        case .framerate:
            framerateChanged(index: indexPath.row)

        case .mediaFile:
            mediaFileChanged(index: indexPath.row)

        case .resolution:
            resolutionChanged(index: indexPath.row)

        default:
            break
        }
    }

    // MARK: - UITextFieldDelegate

    static let numCharSet = CharacterSet(charactersIn: "0123456789")

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard !string.isEmpty else {
            // backspace/delete key is pressed
            return true
        }

        return (textField.keyboardType != .numberPad)
            || (MainViewController.numCharSet.isSuperset(of: CharacterSet(charactersIn: string)))
    }
}
