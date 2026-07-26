import MapKit
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let mapView = MKMapView()
    private let mapUnavailableView = UIView()
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let sourceLabel = UILabel()
    private let coordinateLabel = UILabel()
    private let timingLabel = UILabel()
    private let packetLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let info = content.userInfo
        let isTest = stringValue(info["kind"]) == "notification-test"
        let statusCode = integerValue(info["statusCode"]) ?? 0
        let style = alertStyle(statusCode: statusCode, isTest: isTest)

        statusDot.backgroundColor = style.color
        statusLabel.text = style.label
        sourceLabel.text = (stringValue(info["relaySource"]) ?? "LOCAL MESH REPORT").uppercased()
        packetLabel.text = "PACKET " + (stringValue(info["packetKey"]) ?? "UNKNOWN").uppercased()

        if let reportedAt = doubleValue(info["reportedAt"]) {
            timingLabel.text = relativeTime(from: Date(timeIntervalSince1970: reportedAt))
        } else {
            timingLabel.text = "REPORT TIME UNKNOWN"
        }

        guard let latitude = doubleValue(info["latitude"]),
              let longitude = doubleValue(info["longitude"]),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude),
              latitude != 0 || longitude != 0 else {
            coordinateLabel.text = "LOCATION NOT INCLUDED"
            mapView.isHidden = true
            mapUnavailableView.isHidden = false
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        coordinateLabel.text = String(format: "%.5f, %.5f", latitude, longitude)
        mapView.isHidden = false
        mapUnavailableView.isHidden = true
        mapView.removeAnnotations(mapView.annotations)

        let annotation = SafeRelayAnnotation(color: style.color)
        annotation.coordinate = coordinate
        annotation.title = style.label
        mapView.addAnnotation(annotation)
        mapView.setRegion(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1_800,
                longitudinalMeters: 1_800
            ),
            animated: false
        )
    }

    private func buildInterface() {
        view.backgroundColor = .secondarySystemBackground

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )
        view.addSubview(mapView)

        mapUnavailableView.translatesAutoresizingMaskIntoConstraints = false
        mapUnavailableView.backgroundColor = UIColor(red: 0.055, green: 0.067, blue: 0.082, alpha: 1)
        mapUnavailableView.isHidden = true
        view.addSubview(mapUnavailableView)

        let unavailableSymbol = UIImageView(image: UIImage(systemName: "map.fill"))
        unavailableSymbol.translatesAutoresizingMaskIntoConstraints = false
        unavailableSymbol.tintColor = .secondaryLabel
        unavailableSymbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34)
        mapUnavailableView.addSubview(unavailableSymbol)

        let unavailableLabel = UILabel()
        unavailableLabel.translatesAutoresizingMaskIntoConstraints = false
        unavailableLabel.font = .preferredFont(forTextStyle: .subheadline)
        unavailableLabel.textColor = .secondaryLabel
        unavailableLabel.text = "No incident location in this alert"
        mapUnavailableView.addSubview(unavailableLabel)

        let topBand = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        topBand.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBand)

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.layer.cornerRadius = 5
        topBand.contentView.addSubview(statusDot)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = .white
        topBand.contentView.addSubview(statusLabel)

        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        sourceLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        sourceLabel.textAlignment = .right
        topBand.contentView.addSubview(sourceLabel)

        let detailBand = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        detailBand.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detailBand)

        coordinateLabel.translatesAutoresizingMaskIntoConstraints = false
        coordinateLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        coordinateLabel.textColor = .white
        coordinateLabel.adjustsFontSizeToFitWidth = true
        coordinateLabel.minimumScaleFactor = 0.8
        detailBand.contentView.addSubview(coordinateLabel)

        timingLabel.translatesAutoresizingMaskIntoConstraints = false
        timingLabel.font = .systemFont(ofSize: 11, weight: .medium)
        timingLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        detailBand.contentView.addSubview(timingLabel)

        packetLabel.translatesAutoresizingMaskIntoConstraints = false
        packetLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        packetLabel.textColor = UIColor.white.withAlphaComponent(0.54)
        packetLabel.textAlignment = .right
        packetLabel.adjustsFontSizeToFitWidth = true
        packetLabel.minimumScaleFactor = 0.7
        detailBand.contentView.addSubview(packetLabel)

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            mapUnavailableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapUnavailableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapUnavailableView.topAnchor.constraint(equalTo: view.topAnchor),
            mapUnavailableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            unavailableSymbol.centerXAnchor.constraint(equalTo: mapUnavailableView.centerXAnchor),
            unavailableSymbol.centerYAnchor.constraint(
                equalTo: mapUnavailableView.centerYAnchor,
                constant: -14
            ),
            unavailableLabel.centerXAnchor.constraint(equalTo: mapUnavailableView.centerXAnchor),
            unavailableLabel.topAnchor.constraint(equalTo: unavailableSymbol.bottomAnchor, constant: 10),

            topBand.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBand.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBand.topAnchor.constraint(equalTo: view.topAnchor),
            topBand.heightAnchor.constraint(equalToConstant: 44),
            statusDot.leadingAnchor.constraint(equalTo: topBand.contentView.leadingAnchor, constant: 14),
            statusDot.centerYAnchor.constraint(equalTo: topBand.contentView.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: topBand.contentView.centerYAnchor),
            sourceLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: statusLabel.trailingAnchor,
                constant: 12
            ),
            sourceLabel.trailingAnchor.constraint(
                equalTo: topBand.contentView.trailingAnchor,
                constant: -14
            ),
            sourceLabel.centerYAnchor.constraint(equalTo: topBand.contentView.centerYAnchor),

            detailBand.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailBand.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailBand.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            detailBand.heightAnchor.constraint(equalToConstant: 62),
            coordinateLabel.leadingAnchor.constraint(
                equalTo: detailBand.contentView.leadingAnchor,
                constant: 14
            ),
            coordinateLabel.topAnchor.constraint(equalTo: detailBand.contentView.topAnchor, constant: 10),
            coordinateLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: packetLabel.leadingAnchor,
                constant: -12
            ),
            timingLabel.leadingAnchor.constraint(equalTo: coordinateLabel.leadingAnchor),
            timingLabel.topAnchor.constraint(equalTo: coordinateLabel.bottomAnchor, constant: 5),
            packetLabel.trailingAnchor.constraint(
                equalTo: detailBand.contentView.trailingAnchor,
                constant: -14
            ),
            packetLabel.centerYAnchor.constraint(equalTo: detailBand.contentView.centerYAnchor),
            packetLabel.widthAnchor.constraint(lessThanOrEqualTo: detailBand.widthAnchor, multiplier: 0.44),
        ])
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private func integerValue(_ value: Any?) -> Int? {
        doubleValue(value).map(Int.init)
    }

    private func alertStyle(statusCode: Int, isTest: Bool) -> (label: String, color: UIColor) {
        if isTest {
            return ("NOTIFICATION TEST", UIColor(red: 0.286, green: 0.659, blue: 1, alpha: 1))
        }
        switch statusCode {
        case 1:
            return ("RESCUE NEEDED", UIColor(red: 1, green: 0.302, blue: 0.369, alpha: 1))
        case 2:
            return ("MEDICAL EMERGENCY", UIColor(red: 1, green: 0.482, blue: 0.329, alpha: 1))
        case 3:
            return ("PERSON TRAPPED", UIColor(red: 1, green: 0.69, blue: 0.125, alpha: 1))
        case 4:
            return ("SUPPLIES NEEDED", UIColor(red: 0.949, green: 0.8, blue: 0.376, alpha: 1))
        case 5:
            return ("SHELTER REPORT", UIColor(red: 0.286, green: 0.659, blue: 1, alpha: 1))
        default:
            return ("SAFERELAY ALERT", UIColor.systemGray)
        }
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        switch seconds {
        case 0..<60:
            return "REPORTED JUST NOW"
        case 60..<3_600:
            let minutes = seconds / 60
            return "REPORTED \(minutes) MIN AGO"
        case 3_600..<86_400:
            let hours = seconds / 3_600
            return "REPORTED \(hours) HR AGO"
        default:
            let days = seconds / 86_400
            return "REPORTED \(days) DAY\(days == 1 ? "" : "S") AGO"
        }
    }
}

private final class SafeRelayAnnotation: MKPointAnnotation {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
        super.init()
    }
}

extension NotificationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? SafeRelayAnnotation else {
            return nil
        }
        let identifier = "SafeRelayIncident"
        let marker = mapView.dequeueReusableAnnotationView(
            withIdentifier: identifier
        ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
            annotation: annotation,
            reuseIdentifier: identifier
        )
        marker.annotation = annotation
        marker.markerTintColor = annotation.color
        marker.glyphImage = UIImage(systemName: "exclamationmark")
        marker.glyphTintColor = .white
        marker.canShowCallout = false
        return marker
    }
}
