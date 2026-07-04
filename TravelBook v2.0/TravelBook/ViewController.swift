//
//  ViewController.swift
//  TravelBook
//
//  Created by Yea on 29.08.2022.
//

import UIKit
import MapKit
import CoreLocation
import CoreData

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate {
    
    let newPlaceNotification = Notification.Name("newPlace")
    let regionSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var noteText: UITextField!
    @IBOutlet weak var savePlaceButton: UIButton!
    
    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder()
    
    var latitude = Double()
    var longitude = Double()
    
    var selectedTitle = ""
    var selectedTitleID : UUID?
    
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    var chosenAnnotation: MKPointAnnotation?
    var hasChosenLocation = false
    
    var isViewingSavedPlace: Bool {
        !selectedTitle.isEmpty
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        nameText.delegate = self
        noteText.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        navigationItem.largeTitleDisplayMode = .never
        
        let dismissKeyboardGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissKeyboardGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissKeyboardGesture)
        
        nameText.addTarget(self, action: #selector(textFieldsDidChange), for: .editingChanged)
        noteText.addTarget(self, action: #selector(textFieldsDidChange), for: .editingChanged)
        
        configureViewMode()
        locationManager.requestWhenInUseAuthorization()
        mapView.showsUserLocation = true
        
        if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:)))
        gestureRecognizer.minimumPressDuration = 3
        gestureRecognizer.isEnabled = !isViewingSavedPlace
        mapView.addGestureRecognizer(gestureRecognizer)
        
        if isViewingSavedPlace {
            loadSelectedPlace()
        }
    }
    
    func configureViewMode() {
        title = isViewingSavedPlace ? "Place Details" : "New Place"
        savePlaceButton.isHidden = isViewingSavedPlace
        savePlaceButton.isEnabled = !isViewingSavedPlace
        nameText.isEnabled = !isViewingSavedPlace
        noteText.isEnabled = !isViewingSavedPlace
    }
    
    func loadSelectedPlace() {
        guard let selectedTitleID = selectedTitleID else {
            showAlert(title: "Place Unavailable", message: "The selected place is missing its identifier.")
            return
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Place")
        fetchRequest.predicate = NSPredicate(format: "id == %@", selectedTitleID as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            guard let place = try viewContext.fetch(fetchRequest).first else {
                showAlert(title: "Place Unavailable", message: "The selected place could not be loaded.")
                return
            }
            
            annotationTitle = place.value(forKey: "title") as? String ?? ""
            annotationSubtitle = place.value(forKey: "subtitle") as? String ?? ""
            annotationLatitude = place.value(forKey: "latitude") as? Double ?? 0
            annotationLongitude = place.value(forKey: "longitude") as? Double ?? 0
            
            let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
            let annotation = MKPointAnnotation()
            annotation.title = annotationTitle
            annotation.subtitle = annotationSubtitle
            annotation.coordinate = coordinate
            
            chosenAnnotation = annotation
            hasChosenLocation = true
            latitude = annotationLatitude
            longitude = annotationLongitude
            
            nameText.text = annotationTitle
            noteText.text = annotationSubtitle
            locationManager.stopUpdatingLocation()
            showAnnotation(annotation, centeredAt: coordinate)
        } catch {
            showAlert(title: "Load Failed", message: "The selected place could not be loaded from storage.")
        }
    }
    
    @objc func chooseLocation(gestureRecognizer:UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state == .began {
            
            let touchedPoint = gestureRecognizer.location(in: self.mapView)
            let touchedCoordinate = self.mapView.convert(touchedPoint, toCoordinateFrom: self.mapView)
            
            latitude = touchedCoordinate.latitude
            longitude = touchedCoordinate.longitude
            hasChosenLocation = true
            
            if let chosenAnnotation = chosenAnnotation {
                mapView.removeAnnotation(chosenAnnotation)
            }
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchedCoordinate
            annotation.title = trimmedText(from: nameText)
            annotation.subtitle = trimmedText(from: noteText)
            chosenAnnotation = annotation
            showAnnotation(annotation, centeredAt: touchedCoordinate)
            
        }
        
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            showAlert(title: "Location Access Needed", message: "Enable location access in Settings to center the map on your current position.")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if selectedTitle == "", let coordinate = locations.first?.coordinate {
            centerMap(on: coordinate)
            manager.stopUpdatingLocation()
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation {
            return nil
        }
        
        let reuseID = "Annotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKPinAnnotationView
        
        if pinView == nil {
            
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.purple
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
            
        } else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if isViewingSavedPlace {
            let location = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                if error != nil {
                    self.showAlert(title: "Directions Unavailable", message: "The saved place could not be resolved for Apple Maps directions.")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self.showAlert(title: "Directions Unavailable", message: "The saved place could not be resolved for Apple Maps directions.")
                    return
                }
                
                let placeMark = MKPlacemark(placemark: placemark)
                let item = MKMapItem(placemark: placeMark)
                item.name = self.annotationTitle
                let launchOptions = [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving]
                item.openInMaps(launchOptions: launchOptions)
            }
        }
    }
    
    @IBAction func saveButton(_ sender: Any) {
        guard let title = trimmedText(from: nameText), !title.isEmpty else {
            showAlert(title: "Missing Name", message: "Enter a place name before saving.")
            return
        }
        
        guard hasChosenLocation else {
            showAlert(title: "Location Required", message: "Long-press on the map to choose a location before saving.")
            return
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Place", into: context)
        
        newPlace.setValue(title, forKey: "title")
        newPlace.setValue(trimmedText(from: noteText), forKey: "subtitle")
        newPlace.setValue(latitude, forKey: "latitude")
        newPlace.setValue(longitude, forKey: "longitude")
        newPlace.setValue(UUID(), forKey: "id")
        
        do {
            try context.save()
        } catch {
            showAlert(title: "Save Failed", message: "The place could not be saved right now.")
            return
        }
        
        NotificationCenter.default.post(name: newPlaceNotification, object: nil)
        navigationController?.popViewController(animated: true)
        
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func textFieldsDidChange() {
        chosenAnnotation?.title = trimmedText(from: nameText)
        chosenAnnotation?.subtitle = trimmedText(from: noteText)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameText {
            noteText.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    func trimmedText(from textField: UITextField) -> String? {
        textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func showAnnotation(_ annotation: MKPointAnnotation, centeredAt coordinate: CLLocationCoordinate2D) {
        mapView.addAnnotation(annotation)
        centerMap(on: coordinate)
    }
    
    func centerMap(on coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: coordinate, span: regionSpan)
        mapView.setRegion(region, animated: true)
    }
    
    var viewContext: NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}


