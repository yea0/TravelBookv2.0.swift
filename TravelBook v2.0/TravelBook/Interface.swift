//
//  Interface.swift
//  TravelBook
//
//  Created by Yea on 3.09.2022.
//

import UIKit
import CoreData

class Interface: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let newPlaceNotification = Notification.Name("newPlace")
    
    struct PlaceListItem {
        let title: String
        let id: UUID
    }
    
    @IBOutlet weak var tableView: UITableView!
    var places = [PlaceListItem]()
    var chosenTitle = ""
    var chosenTitleID : UUID?
    var isObservingNewPlace = false
    
    let cellReuseIdentifier = "PlaceCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.topItem?.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(addButtonClicked))
        title = "Places"
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.tableFooterView = UIView()
        
        getData()
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
        
        if !isObservingNewPlace {
            NotificationCenter.default.addObserver(self, selector: #selector(getData), name: newPlaceNotification, object: nil)
            isObservingNewPlace = true
        }
    }
    
    deinit {
        if isObservingNewPlace {
            NotificationCenter.default.removeObserver(self, name: newPlaceNotification, object: nil)
        }
    }
    
    @objc func getData() {
        do {
            let result = try viewContext.fetch(makePlaceFetchRequest())
            places = result.compactMap { place in
                guard let title = place.value(forKey: "title") as? String,
                      let id = place.value(forKey: "id") as? UUID else {
                    return nil
                }
                
                return PlaceListItem(title: title, id: id)
            }
            
            tableView.reloadData()
            
        } catch {
            showAlert(title: "Load Failed", message: "Saved places could not be loaded.")
        }
    }
    
    
    @objc func addButtonClicked() {
        chosenTitle = ""
        chosenTitleID = nil
        performSegue(withIdentifier: "interface", sender: nil)
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.text = places[indexPath.row].title
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        chosenTitle = places[indexPath.row].title
        chosenTitleID = places[indexPath.row].id
        performSegue(withIdentifier: "interface", sender: nil)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            return
        }
        
        let place = places[indexPath.row]
        
        do {
            if let placeToDelete = try viewContext.fetch(makePlaceFetchRequest(id: place.id)).first {
                viewContext.delete(placeToDelete)
                try viewContext.save()
                places.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        } catch {
            showAlert(title: "Delete Failed", message: "The place could not be removed.")
        }
    }
    
    func makePlaceFetchRequest(id: UUID? = nil) -> NSFetchRequest<NSManagedObject> {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Place")
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        if let id = id {
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
        }
        
        return fetchRequest
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "interface" {
            let destinationVC = segue.destination as! ViewController
            destinationVC.selectedTitle = chosenTitle
            destinationVC.selectedTitleID = chosenTitleID
        }
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
