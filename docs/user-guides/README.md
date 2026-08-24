# Pneuman productie-uitbreidingen

Deze map bevat de gebruikershandleidingen voor de Pneuman-uitbreidingen in
Microsoft Dynamics 365 Business Central. De pagina's zijn geschreven in
portable Markdown en gebruiken alleen relatieve afbeeldingspaden. Daardoor
kunnen ze rechtstreeks in de documentatiesite worden opgenomen.

## Handleidingen

- [Frame Specification](frame-specification.md) — een frame-specificatie
  bekijken, afdrukken en als beheerder inrichten.
- [AutoCAD-PIL en productieorder](autocad-pil-production-order.md) — een PIL
  importeren, afwijkingen oplossen, veilig toepassen, routinguren controleren
  en netto meer- en minderwerk naar een bestaande offerte overdragen.

## Voor wie

| Rol | Benodigde rechten | Gebruikt vooral |
| --- | --- | --- |
| Productiemedewerker | `PNE Frame Spec. View` en/of `PNE PIL verwerken` | Rapport bekijken, PIL verwerken |
| Werkvoorbereider | Bovenstaande rechten plus normale productieorderrechten | Verdeling beoordelen en toepassen |
| Verkoopmedewerker | Normale offerte-invoerrechten | Netto meer- en minderwerk controleren |
| Beheerder Frame Specification | `PNE Frame Spec.` | Frame-regels onderhouden |
| Beheerder PIL | `PNE PIL Setup` | PIL-groepen en artikelkoppelingen onderhouden |

> [!IMPORTANT]
> De PIL-rol geeft bewust geen algemene verkooprechten. Wie verschillen naar
> een bestaande offerte zet, heeft daarnaast de normale verkooprechten van de
> organisatie nodig.
