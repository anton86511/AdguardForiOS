/**
       This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
       Copyright © Adguard Software Limited. All rights reserved.
 
       Adguard for iOS is free software: you can redistribute it and/or modify
       it under the terms of the GNU General Public License as published by
       the Free Software Foundation, either version 3 of the License, or
       (at your option) any later version.
 
       Adguard for iOS is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
       GNU General Public License for more details.
 
       You should have received a copy of the GNU General Public License
       along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

class DnsProviderCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: ThemableLabel!
    @IBOutlet weak var descriptionLabel: ThemableLabel?
    @IBOutlet weak var selectedButton: UIButton!
    @IBOutlet weak var arrowRight: UIImageView!
}

class DescriptionCell: UITableViewCell {
    @IBOutlet weak var descriptionLabel: ThemableLabel!
}

class DnsProvidersController: UITableViewController, UIViewControllerTransitioningDelegate, DnsProtocolChangedDelegate {
    
    // MARK: - services
    
    let vpnManager: APVPNManager = ServiceLocator.shared.getService()!
    let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    
    // MARK: Private properties
    private lazy var providers = { self.vpnManager.providers } ()
    private var selectedCellTag = 0
    private var activeProviderObservation: NSKeyValueObservation?
    private var providersObservation: NSKeyValueObservation?
    private var providerToShow: DnsProviderInfo?
    
    private var notificationToken: NotificationToken?
    
    private let descriptionSection = 0
    private let defaultProviderSection = 1
    private let recomendedDescriptionSection = 2
    private let providerSection = 3
    private let addProviderSection = 4
    
    private let defaultProviderTag = -1
    
    // MARK: - view controller life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notificationToken = NotificationCenter.default.observe(name: NSNotification.Name( ConfigurationService.themeChangeNotification), object: nil, queue: OperationQueue.main) {[weak self] (notification) in
            self?.updateTheme()
        }
        
        tableView.rowHeight = UITableView.automaticDimension
        
        let selectCellFunc = { [weak self] in
            guard let self = self else { return }
            if self.vpnManager.activeDnsServer == nil {
                self.selectedCellTag = self.defaultProviderTag
                return
            }
            else {
                let row = self.providers.firstIndex { self.vpnManager.isActiveProvider($0) }
                self.selectedCellTag = row ?? 0
            }
        }
        
        selectCellFunc()
        
        activeProviderObservation = vpnManager.observe(\.activeDnsServer) {[weak self]  (server, change)  in
            DispatchQueue.main.async {
                selectCellFunc()
                self?.tableView.reloadData()
            }
        }
        
        providersObservation = vpnManager.observe(\.providers) {[weak self]  (server, change)  in
            DispatchQueue.main.async {
                guard let sSelf = self else { return }
                sSelf.providers = sSelf.vpnManager.providers
                sSelf.tableView.reloadData()
            }
        }
        
        setupBackButton()
        updateTheme()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "dnsDetailsSegue" {
            let controller = segue.destination as! DnsProviderContainerController
            controller.provider = providerToShow
            controller.defaultDnsServer = defaultServer(providerToShow!)
            controller.delegate = self
        }
    }
    
    // MARK: table view methods
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case descriptionSection:
            let reuseId = "descriptionCell"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as? DescriptionCell else { return UITableViewCell() }
            theme.setupLabel(cell.descriptionLabel)
            theme.setupTableCell(cell)
            return cell
            
        case defaultProviderSection:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DnsServerCell") as! DnsProviderCell
            
            cell.nameLabel.text = String.localizedString("default_dns_server_name")
            cell.descriptionLabel?.text = String.localizedString("default_dns_server_description")
            
            cell.selectedButton.isSelected = selectedCellTag == defaultProviderTag
            cell.selectedButton.tag = defaultProviderTag
            cell.arrowRight.isHidden = true
            
            theme.setupTableCell(cell)
            theme.setupLabel(cell.nameLabel)
            if cell.descriptionLabel != nil {
                theme.setupLabel(cell.descriptionLabel!)
            }
            
            return cell
            
        case providerSection:
            let provider = providers[indexPath.row]
            let custom = vpnManager.isCustomProvider(provider)
            
            let cell = tableView.dequeueReusableCell(withIdentifier: custom ? "CustomDnsServerCell" :"DnsServerCell") as! DnsProviderCell
            
            cell.nameLabel.text = provider.name
            if provider.summary != nil {
                cell.descriptionLabel?.text = ACLocalizedString(provider.summary!, nil)
            }
            
            cell.selectedButton.isSelected = selectedCellTag == indexPath.row
            cell.selectedButton.tag = indexPath.row
            cell.arrowRight.isHidden = false
            
            theme.setupTableCell(cell)
            theme.setupLabel(cell.nameLabel)
            if cell.descriptionLabel != nil {
                theme.setupLabel(cell.descriptionLabel!)
            }
            
            return cell
        
        case recomendedDescriptionSection:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "RecomendedHeaderCell") as? DescriptionCell else { return UITableViewCell() }
            theme.setupLabel(cell.descriptionLabel)
            theme.setupTableCell(cell)
            return cell
            
        case addProviderSection :
            let reuseId = "AddServer"
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) ?? UITableViewCell()
            theme.setupTableCell(cell)
            return cell
            
        default:
            assertionFailure("unknown tableview section")
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case descriptionSection:
            return 1
        case defaultProviderSection:
            return 1
        case recomendedDescriptionSection:
            return 1
        case providerSection:
            return providers.count
        case addProviderSection:
            return 1
        default:
            return 0
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case defaultProviderSection, recomendedDescriptionSection:
            return 0.01 // hide bottom separator
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case providerSection:
            return 0.01 // hide top separator
        default:
            return 0.0
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case defaultProviderSection:
            selectedCellTag = defaultProviderTag
            vpnManager.activeDnsServer = nil
            vpnManager.enabled = true;
            
        case providerSection:
            if vpnManager.isCustomProvider(providers[indexPath.row]) {
                editProvider(providers[indexPath.row])
            }
            else {
                providerToShow = providers[indexPath.row]
                performSegue(withIdentifier: "dnsDetailsSegue", sender: self)
            }
       
        case addProviderSection:
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "NewDnsServerController") as? NewDnsServerController else { return }
            controller.modalPresentationStyle = .custom
            controller.transitioningDelegate = self
            
            present(controller, animated: true, completion: nil)
            
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
        
    // MARK: Actions
    
    @IBAction func selectProviderAction(_ sender: UIButton) {
        var server: DnsServerInfo?
        
        if sender.tag == defaultProviderTag {
            server = nil
        }
        else {
            let provider = providers[sender.tag]
            server = defaultServer(provider)
        }
        
        vpnManager.activeDnsServer = server
        vpnManager.enabled = true;
        
        selectedCellTag = sender.tag
    }
    
    // MARK: - Presentation delegate methods
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomAnimatedTransitioning()
    }
    
    // MARK: - DnsProtocolChangedDelegate method
    
    func changesWereApplied(_ applied: Bool) {
        if !applied {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: String.localizedString("changes_not_applied"))
            }
        }
    }
    
    // MARK: private methods
    
    private func updateTheme() {
        view.backgroundColor = theme.backgroundColor
        theme.setupTable(tableView)
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.tableView.reloadData()
        }
    }
    
    private func editProvider(_ provider: DnsProviderInfo) {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "EditDnsServerController") as? NewDnsServerController else { return }
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = self
        controller.provider = provider
        
        present(controller, animated: true, completion: nil)
    }
    
    private func defaultServer(_ provider: DnsProviderInfo)->DnsServerInfo? {
        
        let doh = provider.servers?.first { (dns) -> Bool in
            return dns.dnsProtocol == DnsProtocol.doh
        }
        
        if doh != nil {
            return doh
        }
        
        let dnsCrypt = provider.servers?.first { (dns) -> Bool in
            return dns.dnsProtocol == DnsProtocol.dnsCrypt
        }
        
        if dnsCrypt != nil {
            return dnsCrypt
        }

        let dot = provider.servers?.first { (dns) -> Bool in
            return dns.dnsProtocol == DnsProtocol.dot
        }

        if dot != nil {
            return dot
        }
        
        let regular = provider.servers?.first { (dns) -> Bool in
            return dns.dnsProtocol == DnsProtocol.dns
        }
        
        if regular != nil {
            return regular
        }
        
        
        return provider.servers?.first
    }
}